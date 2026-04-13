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
