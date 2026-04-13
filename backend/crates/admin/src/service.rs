use argon2::{Argon2, PasswordHash, PasswordVerifier};
use sqlx::PgPool;

use common::error::AppError;
use common::models::{Admin, SystemConfig, User};
use crate::dto::*;

pub struct AdminService;

impl AdminService {
    pub async fn login(db: &PgPool, username: &str, password: &str) -> Result<Admin, AppError> {
        let admin = sqlx::query_as::<_, Admin>(
            "SELECT * FROM admins WHERE username = $1 AND is_active = TRUE"
        )
        .bind(username)
        .fetch_optional(db)
        .await?
        .ok_or_else(|| AppError::BadRequest("Invalid credentials".into()))?;

        let parsed_hash = PasswordHash::new(&admin.password_hash)
            .map_err(|_| AppError::Internal(anyhow::anyhow!("Invalid password hash in database")))?;

        Argon2::default()
            .verify_password(password.as_bytes(), &parsed_hash)
            .map_err(|_| AppError::BadRequest("Invalid credentials".into()))?;

        Ok(admin)
    }

    pub async fn list_users(
        db: &PgPool,
        page: u32,
        page_size: u32,
        phone: Option<&str>,
        nickname: Option<&str>,
    ) -> Result<AdminUserList, AppError> {
        let offset = (page.saturating_sub(1)) * page_size;

        let phone_pattern = phone.map(|p| format!("%{}%", p));
        let nick_pattern = nickname.map(|n| format!("%{}%", n));

        let items = sqlx::query_as::<_, User>(
            "SELECT * FROM users WHERE ($3::text IS NULL OR phone LIKE $3) AND ($4::text IS NULL OR nickname LIKE $4) ORDER BY created_at DESC LIMIT $1 OFFSET $2"
        )
        .bind(page_size as i64)
        .bind(offset as i64)
        .bind(&phone_pattern)
        .bind(&nick_pattern)
        .fetch_all(db)
        .await?;

        let total = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM users WHERE ($1::text IS NULL OR phone LIKE $1) AND ($2::text IS NULL OR nickname LIKE $2)"
        )
        .bind(&phone_pattern)
        .bind(&nick_pattern)
        .fetch_one(db)
        .await?;

        Ok(AdminUserList { items, total })
    }

    pub async fn get_stats(db: &PgPool) -> Result<DashboardStats, AppError> {
        let total_users = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM users")
            .fetch_one(db).await?;
        let total_groups = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM family_groups")
            .fetch_one(db).await?;
        let active_sharing = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM sharing_permissions WHERE status = 'accepted'"
        ).fetch_one(db).await?;
        let today_locations = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM location_records WHERE recorded_at >= CURRENT_DATE"
        ).fetch_one(db).await?;

        Ok(DashboardStats { total_users, total_groups, active_sharing, today_locations })
    }

    pub async fn list_configs(db: &PgPool) -> Result<Vec<SystemConfig>, AppError> {
        let configs = sqlx::query_as::<_, SystemConfig>(
            "SELECT * FROM system_configs ORDER BY key"
        )
        .fetch_all(db)
        .await?;
        Ok(configs)
    }

    pub async fn update_config(
        db: &PgPool,
        key: &str,
        req: &UpdateConfigReq,
    ) -> Result<SystemConfig, AppError> {
        sqlx::query_as::<_, SystemConfig>(
            "UPDATE system_configs SET value = $2, description = COALESCE($3, description), updated_at = NOW() WHERE key = $1 RETURNING *"
        )
        .bind(key)
        .bind(&req.value)
        .bind(&req.description)
        .fetch_optional(db)
        .await?
        .ok_or_else(|| AppError::NotFound("Config key not found".into()))
    }
}
