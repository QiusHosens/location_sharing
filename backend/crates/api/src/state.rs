use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub redis: redis::aio::ConnectionManager,
    pub auth: auth::AuthState,
}

impl AppState {
    pub async fn new() -> anyhow::Result<Self> {
        let database_url = std::env::var("DATABASE_URL")
            .unwrap_or_else(|_| "postgres://postgres:postgres@localhost:5432/location_sharing".into());
        let redis_url = std::env::var("REDIS_URL")
            .unwrap_or_else(|_| "redis://localhost:6379".into());

        let jwt_secret = std::env::var("JWT_SECRET")
            .unwrap_or_else(|_| "dev-jwt-secret-change-me".into());
        let jwt_admin_secret = std::env::var("JWT_ADMIN_SECRET")
            .unwrap_or_else(|_| "dev-admin-jwt-secret-change-me".into());

        let db = PgPool::connect(&database_url).await?;
        sqlx::migrate!("../../migrations").run(&db).await?;

        let redis_client = redis::Client::open(redis_url)?;
        let redis = redis::aio::ConnectionManager::new(redis_client).await?;

        let auth = auth::AuthState {
            jwt_secret,
            jwt_admin_secret,
            access_token_ttl: 3600,
            refresh_token_ttl: 604800,
        };

        Ok(Self { db, redis, auth })
    }
}

impl AsRef<auth::AuthState> for AppState {
    fn as_ref(&self) -> &auth::AuthState {
        &self.auth
    }
}

impl axum::extract::FromRef<AppState> for sqlx::PgPool {
    fn from_ref(state: &AppState) -> Self {
        state.db.clone()
    }
}

impl axum::extract::FromRef<AppState> for redis::aio::ConnectionManager {
    fn from_ref(state: &AppState) -> Self {
        state.redis.clone()
    }
}

impl axum::extract::FromRef<AppState> for auth::AuthState {
    fn from_ref(state: &AppState) -> Self {
        state.auth.clone()
    }
}
