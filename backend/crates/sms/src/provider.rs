use async_trait::async_trait;

#[async_trait]
pub trait SmsProvider: Send + Sync {
    async fn send_code(&self, phone: &str, code: &str) -> anyhow::Result<()>;
}
