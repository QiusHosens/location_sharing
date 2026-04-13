use chrono::{NaiveTime, Utc};
use redis::AsyncCommands;
use sqlx::PgPool;
use uuid::Uuid;

use common::error::AppError;
use crate::dto::*;

pub struct LocationService;

impl LocationService {
    pub async fn upload(
        db: &PgPool,
        redis: &mut redis::aio::ConnectionManager,
        user_id: Uuid,
        req: &UploadLocationReq,
    ) -> Result<(), AppError> {
        let recorded_at = req.recorded_at.unwrap_or_else(|| Utc::now());

        sqlx::query(
            "INSERT INTO location_records (user_id, longitude, latitude, altitude, speed, bearing, accuracy, source, recorded_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)"
        )
        .bind(user_id)
        .bind(req.longitude)
        .bind(req.latitude)
        .bind(req.altitude)
        .bind(req.speed)
        .bind(req.bearing)
        .bind(req.accuracy)
        .bind(&req.source)
        .bind(recorded_at)
        .execute(db)
        .await?;

        let cached = CachedLocation {
            user_id,
            longitude: req.longitude,
            latitude: req.latitude,
            altitude: req.altitude,
            speed: req.speed,
            bearing: req.bearing,
            accuracy: req.accuracy,
            recorded_at,
        };
        let json = serde_json::to_string(&cached)
            .map_err(|e| AppError::Internal(e.into()))?;
        let key = format!("location:latest:{}", user_id);
        let _: () = redis.set_ex(&key, &json, 3600).await
            .map_err(|e| AppError::Internal(e.into()))?;

        Ok(())
    }

    pub async fn get_latest(
        db: &PgPool,
        redis: &mut redis::aio::ConnectionManager,
        user_id: Uuid,
    ) -> Result<Option<CachedLocation>, AppError> {
        let key = format!("location:latest:{}", user_id);
        let cached: Option<String> = redis.get(&key).await.unwrap_or(None);

        if let Some(json) = cached {
            let loc: CachedLocation = serde_json::from_str(&json)
                .map_err(|e| AppError::Internal(e.into()))?;
            return Ok(Some(loc));
        }

        let row = sqlx::query_as::<_, (Uuid, f64, f64, Option<f64>, Option<f32>, Option<f32>, Option<f32>, chrono::DateTime<Utc>)>(
            "SELECT user_id, longitude, latitude, altitude, speed, bearing, accuracy, recorded_at FROM location_records WHERE user_id = $1 ORDER BY recorded_at DESC LIMIT 1"
        )
        .bind(user_id)
        .fetch_optional(db)
        .await?;

        match row {
            Some((uid, lng, lat, alt, spd, brg, acc, ts)) => {
                let loc = CachedLocation {
                    user_id: uid, longitude: lng, latitude: lat,
                    altitude: alt, speed: spd, bearing: brg, accuracy: acc, recorded_at: ts,
                };
                let json = serde_json::to_string(&loc).map_err(|e| AppError::Internal(e.into()))?;
                let _: () = redis.set_ex(&key, &json, 3600).await.map_err(|e| AppError::Internal(e.into()))?;
                Ok(Some(loc))
            }
            None => Ok(None),
        }
    }

    pub async fn get_shared_location(
        db: &PgPool,
        redis: &mut redis::aio::ConnectionManager,
        viewer_id: Uuid,
        owner_id: Uuid,
    ) -> Result<LocationResponse, AppError> {
        let perm = sqlx::query_as::<_, (String, Option<NaiveTime>, Option<NaiveTime>, bool)>(
            "SELECT status, visible_start, visible_end, is_paused FROM sharing_permissions WHERE owner_id = $1 AND viewer_id = $2"
        )
        .bind(owner_id)
        .bind(viewer_id)
        .fetch_optional(db)
        .await?
        .ok_or_else(|| AppError::Forbidden)?;

        let (status, visible_start, visible_end, is_paused) = perm;
        if status != "accepted" || is_paused {
            return Err(AppError::Forbidden);
        }

        if let (Some(start), Some(end)) = (visible_start, visible_end) {
            let now = Utc::now().time();
            if now < start || now > end {
                return Err(AppError::Forbidden);
            }
        }

        let loc = Self::get_latest(db, redis, owner_id).await?
            .ok_or_else(|| AppError::NotFound("No location data".into()))?;

        let nickname = sqlx::query_scalar::<_, Option<String>>("SELECT nickname FROM users WHERE id = $1")
            .bind(owner_id)
            .fetch_optional(db)
            .await?
            .flatten();

        Ok(LocationResponse {
            user_id: owner_id,
            nickname,
            longitude: loc.longitude,
            latitude: loc.latitude,
            altitude: loc.altitude,
            speed: loc.speed,
            bearing: loc.bearing,
            accuracy: loc.accuracy,
            recorded_at: loc.recorded_at,
        })
    }

    pub async fn get_family_locations(
        db: &PgPool,
        redis: &mut redis::aio::ConnectionManager,
        user_id: Uuid,
        group_id: Uuid,
    ) -> Result<Vec<LocationResponse>, AppError> {
        let is_member = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM family_members WHERE group_id = $1 AND user_id = $2)"
        )
        .bind(group_id)
        .bind(user_id)
        .fetch_one(db)
        .await?;

        if !is_member {
            return Err(AppError::Forbidden);
        }

        let member_ids = sqlx::query_scalar::<_, Uuid>(
            "SELECT user_id FROM family_members WHERE group_id = $1 AND user_id != $2"
        )
        .bind(group_id)
        .bind(user_id)
        .fetch_all(db)
        .await?;

        let mut locations = Vec::new();
        for mid in member_ids {
            if let Ok(Some(loc)) = Self::get_latest(db, redis, mid).await {
                let nickname = sqlx::query_scalar::<_, Option<String>>("SELECT nickname FROM users WHERE id = $1")
                    .bind(mid)
                    .fetch_optional(db)
                    .await?
                    .flatten();

                locations.push(LocationResponse {
                    user_id: mid,
                    nickname,
                    longitude: loc.longitude,
                    latitude: loc.latitude,
                    altitude: loc.altitude,
                    speed: loc.speed,
                    bearing: loc.bearing,
                    accuracy: loc.accuracy,
                    recorded_at: loc.recorded_at,
                });
            }
        }

        Ok(locations)
    }
}
