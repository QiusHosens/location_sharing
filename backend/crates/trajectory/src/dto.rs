use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct TrajectoryQuery {
    pub user_id: Uuid,
    pub start_time: DateTime<Utc>,
    pub end_time: DateTime<Utc>,
}

/// 单日汇总：YYYY-MM-DD（按 UTC 日历日切分，每 2 小时一段共 12 段）
#[derive(Debug, Deserialize)]
pub struct DaySummaryQuery {
    pub date: String,
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

#[derive(Debug, Serialize)]
pub struct TrajectorySegmentSummary {
    pub start_time: DateTime<Utc>,
    pub end_time: DateTime<Utc>,
    pub point_count: i64,
}

#[derive(Debug, Serialize)]
pub struct UserTrajectoryDay {
    pub user_id: Uuid,
    pub phone: String,
    pub nickname: Option<String>,
    pub segments: Vec<TrajectorySegmentSummary>,
}

#[derive(Debug, Serialize)]
pub struct DayTrajectorySummaryResponse {
    pub date: String,
    pub users: Vec<UserTrajectoryDay>,
}
