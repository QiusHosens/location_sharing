use axum::{
    extract::FromRequestParts,
    http::request::Parts,
};
use uuid::Uuid;

use crate::service::AuthService;

/// 有 Bearer 且校验通过则为 `Some(user_id)`，否则 `None`（用于允许匿名上传等场景）。
pub struct OptionalAuthUser(pub Option<Uuid>);

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

impl<S> FromRequestParts<S> for OptionalAuthUser
where
    S: Send + Sync + AsRef<crate::AuthState>,
{
    type Rejection = common::error::AppError;

    fn from_request_parts(
        parts: &mut Parts,
        state: &S,
    ) -> impl std::future::Future<Output = Result<Self, Self::Rejection>> + Send {
        let auth = state.as_ref().clone();
        let token_opt = extract_bearer_token(parts).map(|s| s.to_string());
        async move {
            let Some(token) = token_opt else {
                return Ok(OptionalAuthUser(None));
            };
            match AuthService::verify_token(&token, &auth.jwt_secret) {
                Ok(claims) if claims.token_type == crate::dto::TokenType::Access => {
                    match Uuid::parse_str(&claims.sub) {
                        Ok(uid) => Ok(OptionalAuthUser(Some(uid))),
                        Err(_) => Ok(OptionalAuthUser(None)),
                    }
                }
                _ => Ok(OptionalAuthUser(None)),
            }
        }
    }
}

impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync + AsRef<crate::AuthState>,
{
    type Rejection = common::error::AppError;

    fn from_request_parts(
        parts: &mut Parts,
        state: &S,
    ) -> impl std::future::Future<Output = Result<Self, Self::Rejection>> + Send {
        let auth = state.as_ref().clone();
        let token_opt = extract_bearer_token(parts).map(|s| s.to_string());
        async move {
            let token = token_opt.ok_or(common::error::AppError::Unauthorized)?;

            let claims = AuthService::verify_token(&token, &auth.jwt_secret)?;

            if claims.token_type != crate::dto::TokenType::Access {
                return Err(common::error::AppError::Unauthorized);
            }

            let user_id = Uuid::parse_str(&claims.sub)
                .map_err(|_| common::error::AppError::Unauthorized)?;

            Ok(AuthUser(user_id))
        }
    }
}

impl<S> FromRequestParts<S> for AuthAdmin
where
    S: Send + Sync + AsRef<crate::AuthState>,
{
    type Rejection = common::error::AppError;

    fn from_request_parts(
        parts: &mut Parts,
        state: &S,
    ) -> impl std::future::Future<Output = Result<Self, Self::Rejection>> + Send {
        let auth = state.as_ref().clone();
        let token_opt = extract_bearer_token(parts).map(|s| s.to_string());
        async move {
            let token = token_opt.ok_or(common::error::AppError::Unauthorized)?;

            let claims = AuthService::verify_admin_token(&token, &auth.jwt_admin_secret)?;

            let admin_id = Uuid::parse_str(&claims.sub)
                .map_err(|_| common::error::AppError::Unauthorized)?;

            Ok(AuthAdmin {
                admin_id,
                username: claims.username,
            })
        }
    }
}
