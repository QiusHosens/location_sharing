use chrono::{DateTime, NaiveTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use validator::Validate;

#[derive(Debug, Deserialize, Validate)]
pub struct UpdateProfileReq {
    #[validate(length(min = 1, max = 64))]
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Deserialize, Validate)]
pub struct CreateGroupReq {
    #[validate(length(min = 1, max = 100))]
    pub name: String,
}

#[derive(Debug, Deserialize)]
pub struct InviteMemberReq {
    pub phone: String,
}

#[derive(Debug, Deserialize)]
pub struct RespondFamilyInviteReq {
    pub accept: bool,
}

#[derive(Debug, Serialize)]
pub struct FamilyInvitationInfo {
    pub id: Uuid,
    pub group_id: Uuid,
    pub group_name: String,
    pub inviter_id: Uuid,
    pub inviter_phone: String,
    pub inviter_nickname: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct RequestSharingReq {
    /// 对方已注册手机号（与邀请入群一致）
    pub phone: String,
}

#[derive(Debug, Deserialize)]
pub struct RespondSharingReq {
    pub accept: bool,
}

#[derive(Debug, Deserialize)]
pub struct UpdateSharingReq {
    pub is_paused: Option<bool>,
    pub visible_start: Option<NaiveTime>,
    pub visible_end: Option<NaiveTime>,
}

/// 在家庭页开关：是否向同家庭成员共享自己的位置
#[derive(Debug, Deserialize)]
pub struct SetPeerSharingReq {
    pub enabled: bool,
}

#[derive(Debug, Serialize)]
pub struct UserProfile {
    pub id: Uuid,
    pub phone: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct GroupWithMembers {
    pub id: Uuid,
    pub name: String,
    pub creator_id: Uuid,
    pub members: Vec<GroupMemberInfo>,
}

#[derive(Debug, Serialize)]
pub struct GroupMemberInfo {
    pub user_id: Uuid,
    pub phone: String,
    pub nickname: Option<String>,
    pub role: String,
}

/// 公开给 Web/App 的高德配置（不含服务端私钥）
#[derive(Debug, Serialize)]
pub struct MapPublicConfig {
    /// Web JS API Key
    pub web_key: String,
    /// 高德 JS API 2.0 安全密钥（对应 securityJsCode）
    pub web_security_secret: String,
    pub android_key: String,
    pub ios_key: String,
}

#[derive(Debug, Serialize)]
pub struct SharingInfo {
    pub id: Uuid,
    pub owner_id: Uuid,
    pub viewer_id: Uuid,
    pub status: String,
    pub visible_start: Option<NaiveTime>,
    pub visible_end: Option<NaiveTime>,
    pub is_paused: bool,
    pub peer_nickname: Option<String>,
    pub peer_phone: String,
}
