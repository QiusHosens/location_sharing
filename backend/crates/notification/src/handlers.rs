use axum::{
    extract::{Path, Query, State},
    Json,
};
use uuid::Uuid;

use auth::AuthUser;
use common::error::AppError;
use common::response::ApiResponse;
use crate::dto::*;
use crate::service::NotificationService;

pub async fn list_notifications(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Query(q): Query<ListNotificationsQuery>,
) -> Result<Json<ApiResponse<NotificationList>>, AppError> {
    let page = q.page.unwrap_or(1);
    let page_size = q.page_size.unwrap_or(20).min(100);
    let unread_only = q.unread_only.unwrap_or(false);

    let result = NotificationService::list(&db, user_id, page, page_size, unread_only).await?;
    Ok(Json(ApiResponse::ok(result)))
}

pub async fn mark_read(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<()>, AppError> {
    NotificationService::mark_read(&db, user_id, id).await?;
    Ok(ApiResponse::message("Notification marked as read"))
}

pub async fn mark_all_read(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
) -> Result<ApiResponse<()>, AppError> {
    let count = NotificationService::mark_all_read(&db, user_id).await?;
    Ok(ApiResponse::message(format!("{} notifications marked as read", count)))
}
