use serde::{Deserialize, Serialize};
use uuid::Uuid;
use validator::Validate;

#[derive(Debug, Deserialize, Validate)]
pub struct SendCodeReq {
    #[validate(length(min = 11, max = 15, message = "Invalid phone number"))]
    pub phone: String,
}

#[derive(Debug, Deserialize, Validate)]
pub struct VerifyCodeReq {
    #[validate(length(min = 11, max = 15))]
    pub phone: String,
    #[validate(length(equal = 6))]
    pub code: String,
}

#[derive(Debug, Deserialize)]
pub struct RefreshTokenReq {
    pub refresh_token: String,
}

#[derive(Debug, Serialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub token_type: String,
    pub expires_in: i64,
    pub user_id: Uuid,
    pub is_new_user: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,
    pub exp: i64,
    pub iat: i64,
    pub token_type: TokenType,
}

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum TokenType {
    Access,
    Refresh,
    AdminAccess,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AdminClaims {
    pub sub: String,
    pub exp: i64,
    pub iat: i64,
    pub token_type: TokenType,
    pub username: String,
}
