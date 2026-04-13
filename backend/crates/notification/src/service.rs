use sqlx::PgPool;
use uuid::Uuid;

use common::error::AppError;
use common::models::Notification;
use crate::dto::*;

pub struct NotificationService;

impl NotificationService {
    pub async fn list(
        db: &PgPool,
        user_id: Uuid,
        page: u32,
        page_size: u32,
        unread_only: bool,
    ) -> Result<NotificationList, AppError> {
        let offset = (page.saturating_sub(1)) * page_size;

        let (items, total) = if unread_only {
            let items = sqlx::query_as::<_, Notification>(
                "SELECT * FROM notifications WHERE user_id = $1 AND is_read = FALSE ORDER BY created_at DESC LIMIT $2 OFFSET $3"
            )
            .bind(user_id)
            .bind(page_size as i64)
            .bind(offset as i64)
            .fetch_all(db)
            .await?;

            let total = sqlx::query_scalar::<_, i64>(
                "SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = FALSE"
            )
            .bind(user_id)
            .fetch_one(db)
            .await?;

            (items, total)
        } else {
            let items = sqlx::query_as::<_, Notification>(
                "SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3"
            )
            .bind(user_id)
            .bind(page_size as i64)
            .bind(offset as i64)
            .fetch_all(db)
            .await?;

            let total = sqlx::query_scalar::<_, i64>(
                "SELECT COUNT(*) FROM notifications WHERE user_id = $1"
            )
            .bind(user_id)
            .fetch_one(db)
            .await?;

            (items, total)
        };

        let unread_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = FALSE"
        )
        .bind(user_id)
        .fetch_one(db)
        .await?;

        Ok(NotificationList { items, total, unread_count })
    }

    pub async fn mark_read(db: &PgPool, user_id: Uuid, notification_id: Uuid) -> Result<(), AppError> {
        let result = sqlx::query(
            "UPDATE notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2"
        )
        .bind(notification_id)
        .bind(user_id)
        .execute(db)
        .await?;

        if result.rows_affected() == 0 {
            return Err(AppError::NotFound("Notification not found".into()));
        }
        Ok(())
    }

    pub async fn mark_all_read(db: &PgPool, user_id: Uuid) -> Result<u64, AppError> {
        let result = sqlx::query(
            "UPDATE notifications SET is_read = TRUE WHERE user_id = $1 AND is_read = FALSE"
        )
        .bind(user_id)
        .execute(db)
        .await?;

        Ok(result.rows_affected())
    }

    pub async fn create(db: &PgPool, req: &CreateNotificationReq) -> Result<Notification, AppError> {
        let notification = sqlx::query_as::<_, Notification>(
            "INSERT INTO notifications (user_id, type, title, body, data) VALUES ($1, $2, $3, $4, $5) RETURNING *"
        )
        .bind(req.user_id)
        .bind(&req.r#type)
        .bind(&req.title)
        .bind(&req.body)
        .bind(&req.data)
        .fetch_one(db)
        .await?;

        Ok(notification)
    }
}
