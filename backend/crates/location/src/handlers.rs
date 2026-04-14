use axum::{
    extract::{Path, State},
    Json,
};
use uuid::Uuid;

use auth::{AuthUser, OptionalAuthUser};
use common::error::AppError;
use common::response::ApiResponse;
use crate::dto::*;
use crate::service::LocationService;

/// 无需 JWT：未带 `Authorization` 时须在 body 中提供 `user_id`（与移动端上传策略一致）。
pub async fn upload(
    OptionalAuthUser(auth_uid): OptionalAuthUser,
    State(db): State<sqlx::PgPool>,
    State(mut redis): State<redis::aio::ConnectionManager>,
    Json(req): Json<UploadLocationReq>,
) -> Result<ApiResponse<()>, AppError> {
    let user_id = match auth_uid {
        Some(uid) => uid,
        None => req.user_id.ok_or_else(|| {
            AppError::BadRequest("user_id is required when Authorization is absent".into())
        })?,
    };
    LocationService::upload(&db, &mut redis, user_id, &req).await?;
    Ok(ApiResponse::message("Location uploaded"))
}

pub async fn get_latest(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    State(mut redis): State<redis::aio::ConnectionManager>,
) -> Result<Json<ApiResponse<Option<CachedLocation>>>, AppError> {
    let loc = LocationService::get_latest(&db, &mut redis, user_id).await?;
    Ok(Json(ApiResponse::ok(loc)))
}

pub async fn get_shared(
    AuthUser(viewer_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    State(mut redis): State<redis::aio::ConnectionManager>,
    Path(owner_id): Path<Uuid>,
) -> Result<Json<ApiResponse<LocationResponse>>, AppError> {
    let loc = LocationService::get_shared_location(&db, &mut redis, viewer_id, owner_id).await?;
    Ok(Json(ApiResponse::ok(loc)))
}

pub async fn get_family(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    State(mut redis): State<redis::aio::ConnectionManager>,
    Path(group_id): Path<Uuid>,
) -> Result<Json<ApiResponse<Vec<LocationResponse>>>, AppError> {
    let locs = LocationService::get_family_locations(&db, &mut redis, user_id, group_id).await?;
    Ok(Json(ApiResponse::ok(locs)))
}
