use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use common::error::AppError;
use crate::dto::*;

pub struct TrajectoryService;

impl TrajectoryService {
    pub async fn query(
        db: &PgPool,
        viewer_id: Uuid,
        target_user_id: Uuid,
        start_time: DateTime<Utc>,
        end_time: DateTime<Utc>,
    ) -> Result<TrajectoryResponse, AppError> {
        if viewer_id != target_user_id {
            let has_access = sqlx::query_scalar::<_, bool>(
                "SELECT EXISTS(SELECT 1 FROM sharing_permissions WHERE owner_id = $1 AND viewer_id = $2 AND status = 'accepted' AND is_paused = FALSE)"
            )
            .bind(target_user_id)
            .bind(viewer_id)
            .fetch_one(db)
            .await?;

            if !has_access {
                let is_family = sqlx::query_scalar::<_, bool>(
                    "SELECT EXISTS(SELECT 1 FROM family_members fm1 INNER JOIN family_members fm2 ON fm1.group_id = fm2.group_id WHERE fm1.user_id = $1 AND fm2.user_id = $2)"
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
            "SELECT longitude, latitude, altitude, speed, accuracy, recorded_at FROM location_records WHERE user_id = $1 AND recorded_at >= $2 AND recorded_at <= $3 ORDER BY recorded_at ASC"
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
}
