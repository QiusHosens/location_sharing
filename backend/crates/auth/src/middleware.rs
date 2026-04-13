use axum::{
    extract::{FromRequestParts, State},
    http::request::Parts,
};
use uuid::Uuid;

use crate::service::AuthService;

/// Extracts authenticated user_id from JWT Bearer token.
pub struct AuthUser(pub Uuid);

/// Extracts authenticated admin from JWT Bearer token.
pub struct AuthAdmin {
    pub admin_id: Uuid,
    pub username: String,
}

fn extract_bearer_token(parts: &Parts) -> Option<&str> {
    parts
        .headers
        .get("Authorization")?
        .to_str()
        .ok()?
        .strip_prefix("Bearer ")
}

#[axum::async_trait]
impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync + AsRef<crate::AuthState>,
{
    type Rejection = common::error::AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let token = extract_bearer_token(parts)
            .ok_or(common::error::AppError::Unauthorized)?;

        let auth_state: &crate::AuthState = state.as_ref();
        let claims = AuthService::verify_token(token, &auth_state.jwt_secret)?;

        if claims.token_type != crate::dto::TokenType::Access {
            return Err(common::error::AppError::Unauthorized);
        }

        let user_id = Uuid::parse_str(&claims.sub)
            .map_err(|_| common::error::AppError::Unauthorized)?;

        Ok(AuthUser(user_id))
    }
}

#[axum::async_trait]
impl<S> FromRequestParts<S> for AuthAdmin
where
    S: Send + Sync + AsRef<crate::AuthState>,
{
    type Rejection = common::error::AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let token = extract_bearer_token(parts)
            .ok_or(common::error::AppError::Unauthorized)?;

        let auth_state: &crate::AuthState = state.as_ref();
        let claims = AuthService::verify_admin_token(token, &auth_state.jwt_admin_secret)?;

        let admin_id = Uuid::parse_str(&claims.sub)
            .map_err(|_| common::error::AppError::Unauthorized)?;

        Ok(AuthAdmin {
            admin_id,
            username: claims.username,
        })
    }
}
