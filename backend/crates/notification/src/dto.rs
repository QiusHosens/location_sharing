use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct ListNotificationsQuery {
    pub page: Option<u32>,
    pub page_size: Option<u32>,
    pub unread_only: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct NotificationList {
    pub items: Vec<common::models::Notification>,
    pub total: i64,
    pub unread_count: i64,
}

#[derive(Debug, Deserialize)]
pub struct CreateNotificationReq {
    pub user_id: Uuid,
    pub r#type: String,
    pub title: Option<String>,
    pub body: Option<String>,
    pub data: Option<serde_json::Value>,
}
