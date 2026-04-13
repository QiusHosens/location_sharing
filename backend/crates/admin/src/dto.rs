use serde::{Deserialize, Serialize};
use uuid::Uuid;
use validator::Validate;

#[derive(Debug, Deserialize, Validate)]
pub struct AdminLoginReq {
    #[validate(length(min = 1))]
    pub username: String,
    /// 前端对明文口令的 MD5（小写十六进制 32 字符）
    #[validate(length(min = 1))]
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct AdminLoginResponse {
    pub access_token: String,
    pub token_type: String,
    pub admin_id: Uuid,
    pub username: String,
}

#[derive(Debug, Deserialize)]
pub struct AdminUserQuery {
    pub page: Option<u32>,
    pub page_size: Option<u32>,
    pub phone: Option<String>,
    pub nickname: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct AdminUserList {
    pub items: Vec<common::models::User>,
    pub total: i64,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUserStatusReq {
    pub is_active: bool,
}

#[derive(Debug, Deserialize)]
pub struct UpdateConfigReq {
    pub value: serde_json::Value,
    pub description: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct DashboardStats {
    pub total_users: i64,
    pub total_groups: i64,
    pub active_sharing: i64,
    pub today_locations: i64,
}
