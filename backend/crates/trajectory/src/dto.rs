use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct TrajectoryQuery {
    pub user_id: Uuid,
    pub start_time: DateTime<Utc>,
    pub end_time: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct TrajectoryPoint {
    pub longitude: f64,
    pub latitude: f64,
    pub altitude: Option<f64>,
    pub speed: Option<f32>,
    pub accuracy: Option<f32>,
    pub recorded_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct TrajectoryResponse {
    pub user_id: Uuid,
    pub points: Vec<TrajectoryPoint>,
    pub total: i64,
}
