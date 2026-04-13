use chrono::Utc;
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use sqlx::PgPool;
use uuid::Uuid;

use crate::dto::{AdminClaims, Claims, TokenType};
use common::error::AppError;
use common::models::User;

pub struct AuthService;

impl AuthService {
    pub async fn register_user(db: &PgPool, phone: &str, password: &str) -> Result<User, AppError> {
        let hash = bcrypt::hash(password, bcrypt::DEFAULT_COST)
            .map_err(|e| AppError::Internal(e.into()))?;

        let res = sqlx::query_as::<_, User>(
            "INSERT INTO users (phone, password_hash) VALUES ($1, $2) RETURNING *",
        )
        .bind(phone)
        .bind(&hash)
        .fetch_one(db)
        .await;

        match res {
            Ok(user) => Ok(user),
            Err(sqlx::Error::Database(ref d)) if d.code().as_deref() == Some("23505") => {
                Err(AppError::Conflict("该手机号已注册".into()))
            }
            Err(e) => Err(AppError::Database(e)),
        }
    }

    pub async fn login_user(db: &PgPool, phone: &str, password: &str) -> Result<User, AppError> {
        let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE phone = $1")
            .bind(phone)
            .fetch_optional(db)
            .await?
            .ok_or_else(|| AppError::BadRequest("手机号或密码错误".into()))?;

        let hash = user
            .password_hash
            .as_ref()
            .filter(|h| !h.is_empty())
            .ok_or_else(|| AppError::BadRequest("该账号未设置密码，请先注册".into()))?;

        let ok = bcrypt::verify(password, hash)
            .map_err(|_| AppError::BadRequest("手机号或密码错误".into()))?;
        if !ok {
            return Err(AppError::BadRequest("手机号或密码错误".into()));
        }

        Ok(user)
    }

    pub fn generate_tokens(
        user_id: Uuid,
        jwt_secret: &str,
        access_ttl: i64,
        refresh_ttl: i64,
    ) -> Result<(String, String, i64), AppError> {
        let now = Utc::now().timestamp();

        let access_claims = Claims {
            sub: user_id.to_string(),
            exp: now + access_ttl,
            iat: now,
            token_type: TokenType::Access,
        };
        let access_token = encode(
            &Header::default(),
            &access_claims,
            &EncodingKey::from_secret(jwt_secret.as_bytes()),
        )
        .map_err(|e| AppError::Internal(e.into()))?;

        let refresh_claims = Claims {
            sub: user_id.to_string(),
            exp: now + refresh_ttl,
            iat: now,
            token_type: TokenType::Refresh,
        };
        let refresh_token = encode(
            &Header::default(),
            &refresh_claims,
            &EncodingKey::from_secret(jwt_secret.as_bytes()),
        )
        .map_err(|e| AppError::Internal(e.into()))?;

        Ok((access_token, refresh_token, access_ttl))
    }

    pub fn verify_token(token: &str, secret: &str) -> Result<Claims, AppError> {
        let token_data = decode::<Claims>(
            token,
            &DecodingKey::from_secret(secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|_| AppError::Unauthorized)?;

        Ok(token_data.claims)
    }

    pub fn verify_admin_token(token: &str, secret: &str) -> Result<AdminClaims, AppError> {
        let token_data = decode::<AdminClaims>(
            token,
            &DecodingKey::from_secret(secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|_| AppError::Unauthorized)?;

        if token_data.claims.token_type != TokenType::AdminAccess {
            return Err(AppError::Unauthorized);
        }

        Ok(token_data.claims)
    }

    pub fn generate_admin_token(
        admin_id: Uuid,
        username: &str,
        secret: &str,
        ttl: i64,
    ) -> Result<String, AppError> {
        let now = Utc::now().timestamp();
        let claims = AdminClaims {
            sub: admin_id.to_string(),
            exp: now + ttl,
            iat: now,
            token_type: TokenType::AdminAccess,
            username: username.to_string(),
        };
        encode(
            &Header::default(),
            &claims,
            &EncodingKey::from_secret(secret.as_bytes()),
        )
        .map_err(|e| AppError::Internal(e.into()))
    }
}
