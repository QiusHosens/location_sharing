use chrono::{DateTime, Duration, NaiveDate, Utc};
use sqlx::PgPool;
use std::collections::HashMap;
use std::collections::HashSet;
use uuid::Uuid;

use common::error::AppError;
use crate::dto::*;

pub struct TrajectoryService;

const SEGMENT_SECS: i64 = 2 * 3600;
const SEGMENTS_PER_DAY: usize = 12;

impl TrajectoryService {
    /// 当前用户可查看轨迹的用户：本人、同家庭组成员、向自己共享了位置的成员
    async fn visible_user_ids(db: &PgPool, viewer_id: Uuid) -> Result<Vec<Uuid>, AppError> {
        let mut ids: HashSet<Uuid> = HashSet::new();
        ids.insert(viewer_id);

        let family: Vec<Uuid> = sqlx::query_scalar(
            "SELECT DISTINCT fm2.user_id FROM family_members fm1
             INNER JOIN family_members fm2 ON fm1.group_id = fm2.group_id
             WHERE fm1.user_id = $1",
        )
        .bind(viewer_id)
        .fetch_all(db)
        .await?;
        ids.extend(family);

        let shared: Vec<Uuid> = sqlx::query_scalar(
            "SELECT owner_id FROM sharing_permissions
             WHERE viewer_id = $1 AND status = 'accepted' AND is_paused = FALSE",
        )
        .bind(viewer_id)
        .fetch_all(db)
        .await?;
        ids.extend(shared);

        Ok(ids.into_iter().collect())
    }

    pub async fn query(
        db: &PgPool,
        viewer_id: Uuid,
        target_user_id: Uuid,
        start_time: DateTime<Utc>,
        end_time: DateTime<Utc>,
    ) -> Result<TrajectoryResponse, AppError> {
        if viewer_id != target_user_id {
            let has_access = sqlx::query_scalar::<_, bool>(
                "SELECT EXISTS(SELECT 1 FROM sharing_permissions WHERE owner_id = $1 AND viewer_id = $2 AND status = 'accepted' AND is_paused = FALSE)",
            )
            .bind(target_user_id)
            .bind(viewer_id)
            .fetch_one(db)
            .await?;

            if !has_access {
                let is_family = sqlx::query_scalar::<_, bool>(
                    "SELECT EXISTS(SELECT 1 FROM family_members fm1 INNER JOIN family_members fm2 ON fm1.group_id = fm2.group_id WHERE fm1.user_id = $1 AND fm2.user_id = $2)",
                )
                .bind(viewer_id)
                .bind(target_user_id)
                .fetch_one(db)
                .await?;

                if !is_family {
                    return Err(AppError::Forbidden);
                }
            }
        }

        let points = sqlx::query_as::<_, (f64, f64, Option<f64>, Option<f32>, Option<f32>, DateTime<Utc>)>(
            "SELECT longitude, latitude, altitude, speed, accuracy, recorded_at FROM location_records WHERE user_id = $1 AND recorded_at >= $2 AND recorded_at < $3 ORDER BY recorded_at ASC"
        )
        .bind(target_user_id)
        .bind(start_time)
        .bind(end_time)
        .fetch_all(db)
        .await?;

        let total = points.len() as i64;
        let trajectory_points = points.into_iter().map(|(lng, lat, alt, spd, acc, ts)| {
            TrajectoryPoint {
                longitude: lng,
                latitude: lat,
                altitude: alt,
                speed: spd,
                accuracy: acc,
                recorded_at: ts,
            }
        }).collect();

        Ok(TrajectoryResponse {
            user_id: target_user_id,
            points: trajectory_points,
            total,
        })
    }

    /// 指定 UTC 日历日内，按用户、按 2 小时分段汇总轨迹点数量（用于列表；详情仍用 [Self::query]）
    pub async fn query_day_summary(
        db: &PgPool,
        viewer_id: Uuid,
        date_str: &str,
    ) -> Result<DayTrajectorySummaryResponse, AppError> {
        let date = NaiveDate::parse_from_str(date_str.trim(), "%Y-%m-%d")
            .map_err(|_| AppError::BadRequest("date must be YYYY-MM-DD".into()))?;
        let day_start = date
            .and_hms_opt(0, 0, 0)
            .ok_or_else(|| AppError::BadRequest("invalid date".into()))?
            .and_utc();
        let day_end = day_start + Duration::days(1);

        let user_ids = Self::visible_user_ids(db, viewer_id).await?;
        if user_ids.is_empty() {
            return Ok(DayTrajectorySummaryResponse {
                date: date_str.to_string(),
                users: vec![],
            });
        }

        let rows = sqlx::query_as::<_, (Uuid, String, Option<String>, DateTime<Utc>)>(
            "SELECT lr.user_id, u.phone, u.nickname, lr.recorded_at
             FROM location_records lr
             INNER JOIN users u ON u.id = lr.user_id
             WHERE lr.user_id = ANY($1) AND lr.recorded_at >= $2 AND lr.recorded_at < $3
             ORDER BY lr.user_id, lr.recorded_at",
        )
        .bind(&user_ids)
        .bind(day_start)
        .bind(day_end)
        .fetch_all(db)
        .await?;

        struct Acc {
            phone: String,
            nickname: Option<String>,
            counts: [i64; SEGMENTS_PER_DAY],
        }

        let mut map: HashMap<Uuid, Acc> = HashMap::new();
        for (uid, phone, nickname, ts) in rows {
            let acc = map.entry(uid).or_insert_with(|| Acc {
                phone: String::new(),
                nickname: None,
                counts: [0; SEGMENTS_PER_DAY],
            });
            acc.phone = phone;
            acc.nickname = nickname;
            let offset = (ts - day_start).num_seconds();
            if offset < 0 {
                continue;
            }
            let idx = (offset / SEGMENT_SECS).min((SEGMENTS_PER_DAY - 1) as i64) as usize;
            acc.counts[idx] += 1;
        }

        let mut users: Vec<UserTrajectoryDay> = map
            .into_iter()
            .filter(|(_, a)| a.counts.iter().any(|&c| c > 0))
            .map(|(uid, a)| {
                let mut segments = Vec::new();
                for i in 0..SEGMENTS_PER_DAY {
                    if a.counts[i] == 0 {
                        continue;
                    }
                    let seg_start = day_start + Duration::seconds(i as i64 * SEGMENT_SECS);
                    let seg_end = day_start + Duration::seconds((i as i64 + 1) * SEGMENT_SECS);
                    segments.push(TrajectorySegmentSummary {
                        start_time: seg_start,
                        end_time: seg_end,
                        point_count: a.counts[i],
                    });
                }
                UserTrajectoryDay {
                    user_id: uid,
                    phone: a.phone,
                    nickname: a.nickname,
                    segments,
                }
            })
            .collect();

        users.sort_by(|a, b| a.phone.cmp(&b.phone));

        Ok(DayTrajectorySummaryResponse {
            date: date_str.to_string(),
            users,
        })
    }
}
