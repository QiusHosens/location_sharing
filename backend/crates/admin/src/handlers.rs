use axum::{
    extract::{Path, Query, State},
    Json,
};
use validator::Validate;

use auth::{AuthAdmin, AuthService, AuthState};
use common::error::AppError;
use common::response::ApiResponse;
use crate::dto::*;
use crate::service::AdminService;

pub async fn login(
    State(db): State<sqlx::PgPool>,
    State(auth_state): State<AuthState>,
    Json(req): Json<AdminLoginReq>,
) -> Result<Json<ApiResponse<AdminLoginResponse>>, AppError> {
    req.validate().map_err(|e| AppError::Validation(e.to_string()))?;

    let admin = AdminService::login(&db, &req.username, &req.password).await?;

    let token = AuthService::generate_admin_token(
        admin.id,
        &admin.username,
        &auth_state.jwt_admin_secret,
        auth_state.access_token_ttl,
    )?;

    Ok(Json(ApiResponse::ok(AdminLoginResponse {
        access_token: token,
        token_type: "Bearer".into(),
        admin_id: admin.id,
        username: admin.username,
    })))
}

pub async fn list_users(
    AuthAdmin { .. }: AuthAdmin,
    State(db): State<sqlx::PgPool>,
    Query(q): Query<AdminUserQuery>,
) -> Result<Json<ApiResponse<AdminUserList>>, AppError> {
    let page = q.page.unwrap_or(1);
    let page_size = q.page_size.unwrap_or(20).min(100);
    let result = AdminService::list_users(
        &db, page, page_size,
        q.phone.as_deref(), q.nickname.as_deref(),
    ).await?;
    Ok(Json(ApiResponse::ok(result)))
}

pub async fn get_stats(
    AuthAdmin { .. }: AuthAdmin,
    State(db): State<sqlx::PgPool>,
) -> Result<Json<ApiResponse<DashboardStats>>, AppError> {
    let stats = AdminService::get_stats(&db).await?;
    Ok(Json(ApiResponse::ok(stats)))
}

pub async fn list_configs(
    AuthAdmin { .. }: AuthAdmin,
    State(db): State<sqlx::PgPool>,
) -> Result<Json<ApiResponse<Vec<common::models::SystemConfig>>>, AppError> {
    let configs = AdminService::list_configs(&db).await?;
    Ok(Json(ApiResponse::ok(configs)))
}

pub async fn update_config(
    AuthAdmin { .. }: AuthAdmin,
    State(db): State<sqlx::PgPool>,
    Path(key): Path<String>,
    Json(req): Json<UpdateConfigReq>,
) -> Result<Json<ApiResponse<common::models::SystemConfig>>, AppError> {
    let config = AdminService::update_config(&db, &key, &req).await?;
    Ok(Json(ApiResponse::ok(config)))
}
