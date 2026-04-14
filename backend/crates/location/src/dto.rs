use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct UploadLocationReq {
    /// 未带 Authorization 时必填，用于匿名上传（与 JWT 同时存在时以 JWT 为准）
    pub user_id: Option<Uuid>,
    pub longitude: f64,
    pub latitude: f64,
    pub altitude: Option<f64>,
    pub speed: Option<f32>,
    pub bearing: Option<f32>,
    pub accuracy: Option<f32>,
    pub source: Option<String>,
    pub recorded_at: Option<DateTime<Utc>>,
    /// 设备电量 0–100
    pub battery_level: Option<i16>,
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
    pub battery_level: Option<i16>,
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
    #[serde(default)]
    pub battery_level: Option<i16>,
}
