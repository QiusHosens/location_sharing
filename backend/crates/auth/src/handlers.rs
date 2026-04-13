use axum::{extract::State, Json};
use validator::Validate;

use crate::dto::{RefreshTokenReq, SendCodeReq, TokenResponse, TokenType, VerifyCodeReq};
use crate::service::AuthService;
use common::error::AppError;
use common::response::ApiResponse;

use std::sync::Arc;

/// State required by auth handlers — implemented by AppState via clone fields.
pub struct AuthHandlerState {
    pub db: sqlx::PgPool,
    pub redis: redis::aio::ConnectionManager,
    pub jwt_secret: String,
    pub access_token_ttl: i64,
    pub refresh_token_ttl: i64,
}

pub async fn send_code(
    State(db): State<sqlx::PgPool>,
    State(mut redis): State<redis::aio::ConnectionManager>,
    Json(req): Json<SendCodeReq>,
) -> Result<ApiResponse<()>, AppError> {
    req.validate().map_err(|e| AppError::Validation(e.to_string()))?;

    let code = AuthService::generate_code();
    AuthService::store_code(&mut redis, &req.phone, &code, 300).await?;

    tracing::info!(phone = %req.phone, code = %code, "Verification code generated (dev mode)");

    Ok(ApiResponse::message("Verification code sent"))
}

pub async fn verify_code(
    State(db): State<sqlx::PgPool>,
    State(mut redis): State<redis::aio::ConnectionManager>,
    State(auth): State<crate::AuthState>,
    Json(req): Json<VerifyCodeReq>,
) -> Result<Json<ApiResponse<TokenResponse>>, AppError> {
    req.validate().map_err(|e| AppError::Validation(e.to_string()))?;

    let valid = AuthService::verify_code(&mut redis, &req.phone, &req.code).await?;
    if !valid {
        return Err(AppError::BadRequest("Invalid or expired verification code".into()));
    }

    let (user, is_new_user) = AuthService::find_or_create_user(&db, &req.phone).await?;

    let (access_token, refresh_token, expires_in) = AuthService::generate_tokens(
        user.id,
        &auth.jwt_secret,
        auth.access_token_ttl,
        auth.refresh_token_ttl,
    )?;

    Ok(Json(ApiResponse::ok(TokenResponse {
        access_token,
        refresh_token,
        token_type: "Bearer".into(),
        expires_in,
        user_id: user.id,
        is_new_user,
    })))
}

pub async fn refresh_token(
    State(auth): State<crate::AuthState>,
    Json(req): Json<RefreshTokenReq>,
) -> Result<Json<ApiResponse<TokenResponse>>, AppError> {
    let claims = AuthService::verify_token(&req.refresh_token, &auth.jwt_secret)?;

    if claims.token_type != TokenType::Refresh {
        return Err(AppError::BadRequest("Invalid token type".into()));
    }

    let user_id = uuid::Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::Unauthorized)?;

    let (access_token, refresh_token, expires_in) = AuthService::generate_tokens(
        user_id,
        &auth.jwt_secret,
        auth.access_token_ttl,
        auth.refresh_token_ttl,
    )?;

    Ok(Json(ApiResponse::ok(TokenResponse {
        access_token,
        refresh_token,
        token_type: "Bearer".into(),
        expires_in,
        user_id,
        is_new_user: false,
    })))
}
