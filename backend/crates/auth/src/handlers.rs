use axum::{extract::State, Json};
use validator::Validate;

use crate::dto::{LoginReq, RefreshTokenReq, RegisterReq, TokenResponse, TokenType};
use crate::service::AuthService;
use common::error::AppError;
use common::response::ApiResponse;

pub async fn register(
    State(db): State<sqlx::PgPool>,
    State(auth): State<crate::AuthState>,
    Json(req): Json<RegisterReq>,
) -> Result<Json<ApiResponse<TokenResponse>>, AppError> {
    req.validate()
        .map_err(|e| AppError::Validation(e.to_string()))?;

    let user = AuthService::register_user(&db, &req.phone, &req.password).await?;

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
        is_new_user: true,
    })))
}

pub async fn login(
    State(db): State<sqlx::PgPool>,
    State(auth): State<crate::AuthState>,
    Json(req): Json<LoginReq>,
) -> Result<Json<ApiResponse<TokenResponse>>, AppError> {
    req.validate()
        .map_err(|e| AppError::Validation(e.to_string()))?;

    let user = AuthService::login_user(&db, &req.phone, &req.password).await?;

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
        is_new_user: false,
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

    let user_id = uuid::Uuid::parse_str(&claims.sub).map_err(|_| AppError::Unauthorized)?;

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
