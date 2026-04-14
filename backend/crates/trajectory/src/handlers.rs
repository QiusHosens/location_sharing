use axum::{extract::{Query, State}, Json};

use auth::AuthUser;
use common::error::AppError;
use common::response::ApiResponse;
use crate::dto::*;
use crate::service::TrajectoryService;

pub async fn query_trajectory(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Query(q): Query<TrajectoryQuery>,
) -> Result<Json<ApiResponse<TrajectoryResponse>>, AppError> {
    if q.start_time >= q.end_time {
        return Err(AppError::BadRequest("start_time must be before end_time".into()));
    }

    let result = TrajectoryService::query(&db, user_id, q.user_id, q.start_time, q.end_time).await?;
    Ok(Json(ApiResponse::ok(result)))
}

pub async fn query_day_summary(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Query(q): Query<DaySummaryQuery>,
) -> Result<Json<ApiResponse<DayTrajectorySummaryResponse>>, AppError> {
    if q.date.trim().is_empty() {
        return Err(AppError::BadRequest("date is required".into()));
    }
    let result = TrajectoryService::query_day_summary(&db, user_id, &q.date).await?;
    Ok(Json(ApiResponse::ok(result)))
}
