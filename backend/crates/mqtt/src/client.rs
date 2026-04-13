use rumqttc::{AsyncClient, EventLoop, MqttOptions, QoS};
use std::time::Duration;
use tokio::sync::mpsc;

pub struct MqttBridge {
    client: AsyncClient,
    event_tx: mpsc::Sender<rumqttc::Event>,
}

impl MqttBridge {
    pub async fn new(host: &str, port: u16, client_id: &str) -> anyhow::Result<(Self, EventLoop)> {
        let mut opts = MqttOptions::new(client_id, host, port);
        opts.set_keep_alive(Duration::from_secs(30));
        opts.set_clean_session(true);

        let (client, event_loop) = AsyncClient::new(opts, 100);
        let (event_tx, _event_rx) = mpsc::channel(256);

        Ok((Self { client, event_tx }, event_loop))
    }

    pub async fn publish_location(
        &self,
        user_id: &uuid::Uuid,
        payload: &[u8],
    ) -> anyhow::Result<()> {
        let topic = format!("location/{}/update", user_id);
        self.client
            .publish(topic, QoS::AtLeastOnce, false, payload)
            .await?;
        Ok(())
    }

    pub async fn subscribe_location(&self, user_id: &uuid::Uuid) -> anyhow::Result<()> {
        let topic = format!("location/{}/update", user_id);
        self.client.subscribe(&topic, QoS::AtLeastOnce).await?;
        Ok(())
    }

    pub async fn publish(&self, topic: &str, payload: &[u8]) -> anyhow::Result<()> {
        self.client
            .publish(topic, QoS::AtLeastOnce, false, payload)
            .await?;
        Ok(())
    }

    pub fn client(&self) -> &AsyncClient {
        &self.client
    }
}
