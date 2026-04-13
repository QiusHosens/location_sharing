use rumqttc::{Event, EventLoop, Packet};
use tracing;

pub async fn run_event_loop(mut event_loop: EventLoop) {
    loop {
        match event_loop.poll().await {
            Ok(event) => {
                if let Event::Incoming(Packet::Publish(publish)) = event {
                    tracing::debug!(
                        topic = %publish.topic,
                        payload_len = publish.payload.len(),
                        "MQTT message received"
                    );
                }
            }
            Err(e) => {
                tracing::error!("MQTT event loop error: {:?}", e);
                tokio::time::sleep(std::time::Duration::from_secs(5)).await;
            }
        }
    }
}
