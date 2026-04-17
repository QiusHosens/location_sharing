use chrono::{DateTime, FixedOffset, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct TrajectoryQuery {
    pub user_id: Uuid,
    pub start_time: DateTime<Utc>,
    pub end_time: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct OptimizedTrajectoryQuery {
    pub user_id: Uuid,
    pub start_time: DateTime<Utc>,
    pub end_time: DateTime<Utc>,
    /// Douglas-Peucker 容差（米），默认 10
    pub tolerance: Option<f64>,
    /// 最大合理速度（m/s），超过视为漂移，默认 80
    pub max_speed: Option<f64>,
    /// 平滑半径，默认 1
    pub smooth_radius: Option<usize>,
}

/// 单日汇总：YYYY-MM-DD（按东八区日历日切分，每 2 小时一段共 12 段）
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
    pub start_time: DateTime<FixedOffset>,
    pub end_time: DateTime<FixedOffset>,
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
