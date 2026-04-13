use std::path::Path;

use sha2::{Digest, Sha384};
use sqlx::PgPool;

/// 与 sqlx 内置迁移一致：`Sha384::digest(sql.as_bytes())`（见 sqlx-core `Migration::new`）
fn sha384_checksum(sql: &str) -> Vec<u8> {
    Sha384::digest(sql.as_bytes()).to_vec()
}

/// 开发用：仓库里改过已应用的 `NNN_*.sql` 后，sqlx 会报 “migration N was previously applied but has been modified”。  
/// 在设 `SQLX_MIGRATE_REPAIR=1` 时，用当前磁盘上迁移文件的 SHA384 覆盖 `_sqlx_migrations.checksum`，勿在生产环境使用。
async fn repair_sqlx_migration_checksums(pool: &PgPool) -> anyhow::Result<()> {
    let exists: bool = sqlx::query_scalar(
        "SELECT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = '_sqlx_migrations'
        )",
    )
    .fetch_one(pool)
    .await?;

    if !exists {
        return Ok(());
    }

    let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../migrations");
    let mut entries: Vec<_> = std::fs::read_dir(&dir)?
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .filter(|p| p.extension().is_some_and(|x| x == "sql"))
        .collect();
    entries.sort();

    for path in entries {
        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .ok_or_else(|| anyhow::anyhow!("invalid migration path"))?;
        let version_str = name.split('_').next().ok_or_else(|| anyhow::anyhow!("bad migration name"))?;
        let version: i64 = version_str.parse()?;

        let sql = std::fs::read_to_string(&path)?;
        let checksum = sha384_checksum(&sql);

        let n = sqlx::query("UPDATE _sqlx_migrations SET checksum = $1 WHERE version = $2")
            .bind(&checksum)
            .bind(version)
            .execute(pool)
            .await?
            .rows_affected();

        if n > 0 {
            tracing::info!(
                "SQLX_MIGRATE_REPAIR: updated checksum for migration version {}",
                version
            );
        }
    }

    Ok(())
}

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

        if std::env::var("SQLX_MIGRATE_REPAIR")
            .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
            .unwrap_or(false)
        {
            tracing::warn!("SQLX_MIGRATE_REPAIR is set: syncing _sqlx_migrations checksums from disk (dev only)");
            repair_sqlx_migration_checksums(&db).await?;
        }

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
