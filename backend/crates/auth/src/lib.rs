pub mod handlers;
pub mod service;
pub mod middleware;
pub mod dto;

pub use dto::{Claims, TokenType, AdminClaims};
pub use middleware::{AuthUser, AuthAdmin};
pub use service::AuthService;

/// Minimal auth-related state that AppState must provide via AsRef.
#[derive(Clone)]
pub struct AuthState {
    pub jwt_secret: String,
    pub jwt_admin_secret: String,
    pub access_token_ttl: i64,
    pub refresh_token_ttl: i64,
}
