use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct UploadLocationReq {
    pub longitude: f64,
    pub latitude: f64,
    pub altitude: Option<f64>,
    pub speed: Option<f32>,
    pub bearing: Option<f32>,
    pub accuracy: Option<f32>,
    pub source: Option<String>,
    pub recorded_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize)]
pub struct LocationResponse {
    pub user_id: Uuid,
    pub nickname: Option<String>,
    pub longitude: f64,
    pub latitude: f64,
    pub altitude: Option<f64>,
    pub speed: Option<f32>,
    pub bearing: Option<f32>,
    pub accuracy: Option<f32>,
    pub recorded_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CachedLocation {
    pub user_id: Uuid,
    pub longitude: f64,
    pub latitude: f64,
    pub altitude: Option<f64>,
    pub speed: Option<f32>,
    pub bearing: Option<f32>,
    pub accuracy: Option<f32>,
    pub recorded_at: DateTime<Utc>,
}
