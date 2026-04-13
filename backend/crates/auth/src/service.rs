use chrono::Utc;
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use rand::Rng;
use redis::AsyncCommands;
use sqlx::PgPool;
use uuid::Uuid;

use crate::dto::{AdminClaims, Claims, TokenResponse, TokenType};
use common::error::AppError;
use common::models::User;

pub struct AuthService;

impl AuthService {
    pub fn generate_code() -> String {
        let mut rng = rand::thread_rng();
        format!("{:06}", rng.gen_range(0..1_000_000))
    }

    pub async fn store_code(
        redis: &mut redis::aio::ConnectionManager,
        phone: &str,
        code: &str,
        ttl_seconds: u64,
    ) -> Result<(), AppError> {
        let key = format!("sms:code:{}", phone);
        let rate_key = format!("sms:rate:{}", phone);

        let count: Option<i32> = redis.get(&rate_key).await.unwrap_or(None);
        if count.unwrap_or(0) >= 10 {
            return Err(AppError::BadRequest("Too many SMS requests today".into()));
        }

        let _: () = redis.set_ex(&key, code, ttl_seconds).await
            .map_err(|e| AppError::Internal(e.into()))?;

        let _: () = redis.incr(&rate_key, 1i32).await
            .map_err(|e| AppError::Internal(e.into()))?;
        let ttl: i64 = redis.ttl(&rate_key).await.unwrap_or(-1);
        if ttl < 0 {
            let _: () = redis.expire(&rate_key, 86400).await
                .map_err(|e| AppError::Internal(e.into()))?;
        }

        Ok(())
    }

    pub async fn verify_code(
        redis: &mut redis::aio::ConnectionManager,
        phone: &str,
        code: &str,
    ) -> Result<bool, AppError> {
        let key = format!("sms:code:{}", phone);
        let stored: Option<String> = redis.get(&key).await
            .map_err(|e| AppError::Internal(e.into()))?;

        match stored {
            Some(stored_code) if stored_code == code => {
                let _: () = redis.del(&key).await
                    .map_err(|e| AppError::Internal(e.into()))?;
                Ok(true)
            }
            _ => Ok(false),
        }
    }

    pub async fn find_or_create_user(
        db: &PgPool,
        phone: &str,
    ) -> Result<(User, bool), AppError> {
        let existing = sqlx::query_as::<_, User>(
            "SELECT * FROM users WHERE phone = $1"
        )
        .bind(phone)
        .fetch_optional(db)
        .await?;

        if let Some(user) = existing {
            return Ok((user, false));
        }

        let user = sqlx::query_as::<_, User>(
            "INSERT INTO users (phone) VALUES ($1) RETURNING *"
        )
        .bind(phone)
        .fetch_one(db)
        .await?;

        Ok((user, true))
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
        ).map_err(|e| AppError::Internal(e.into()))?;

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
        ).map_err(|e| AppError::Internal(e.into()))?;

        Ok((access_token, refresh_token, access_ttl))
    }

    pub fn verify_token(token: &str, secret: &str) -> Result<Claims, AppError> {
        let token_data = decode::<Claims>(
            token,
            &DecodingKey::from_secret(secret.as_bytes()),
            &Validation::default(),
        ).map_err(|_| AppError::Unauthorized)?;

        Ok(token_data.claims)
    }

    pub fn verify_admin_token(token: &str, secret: &str) -> Result<AdminClaims, AppError> {
        let token_data = decode::<AdminClaims>(
            token,
            &DecodingKey::from_secret(secret.as_bytes()),
            &Validation::default(),
        ).map_err(|_| AppError::Unauthorized)?;

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
        ).map_err(|e| AppError::Internal(e.into()))
    }
}
