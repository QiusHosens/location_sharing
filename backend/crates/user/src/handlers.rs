use axum::{
    extract::{Path, State},
    Json,
};
use uuid::Uuid;
use validator::Validate;

use auth::AuthUser;
use common::error::AppError;
use common::response::ApiResponse;
use crate::dto::*;
use crate::service::UserService;

pub async fn get_profile(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
) -> Result<Json<ApiResponse<UserProfile>>, AppError> {
    let user = UserService::get_profile(&db, user_id).await?;
    Ok(Json(ApiResponse::ok(UserProfile {
        id: user.id,
        phone: user.phone,
        nickname: user.nickname,
        avatar_url: user.avatar_url,
    })))
}

pub async fn update_profile(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Json(req): Json<UpdateProfileReq>,
) -> Result<Json<ApiResponse<UserProfile>>, AppError> {
    req.validate().map_err(|e| AppError::Validation(e.to_string()))?;
    let user = UserService::update_profile(&db, user_id, &req).await?;
    Ok(Json(ApiResponse::ok(UserProfile {
        id: user.id,
        phone: user.phone,
        nickname: user.nickname,
        avatar_url: user.avatar_url,
    })))
}

pub async fn create_group(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Json(req): Json<CreateGroupReq>,
) -> Result<Json<ApiResponse<common::models::FamilyGroup>>, AppError> {
    req.validate().map_err(|e| AppError::Validation(e.to_string()))?;
    let group = UserService::create_group(&db, user_id, &req.name).await?;
    Ok(Json(ApiResponse::ok(group)))
}

pub async fn list_groups(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
) -> Result<Json<ApiResponse<Vec<GroupWithMembers>>>, AppError> {
    let groups = UserService::list_groups(&db, user_id).await?;
    Ok(Json(ApiResponse::ok(groups)))
}

pub async fn delete_group(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Path(group_id): Path<Uuid>,
) -> Result<ApiResponse<()>, AppError> {
    UserService::delete_group(&db, user_id, group_id).await?;
    Ok(ApiResponse::message("Group deleted"))
}

pub async fn add_member(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Path(group_id): Path<Uuid>,
    Json(req): Json<InviteMemberReq>,
) -> Result<ApiResponse<()>, AppError> {
    UserService::add_member(&db, user_id, group_id, &req.phone).await?;
    Ok(ApiResponse::message("Member added"))
}

pub async fn remove_member(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Path((group_id, member_id)): Path<(Uuid, Uuid)>,
) -> Result<ApiResponse<()>, AppError> {
    UserService::remove_member(&db, user_id, group_id, member_id).await?;
    Ok(ApiResponse::message("Member removed"))
}

pub async fn request_sharing(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Json(req): Json<RequestSharingReq>,
) -> Result<Json<ApiResponse<common::models::SharingPermission>>, AppError> {
    let perm = UserService::request_sharing(&db, user_id, req.target_user_id).await?;
    Ok(Json(ApiResponse::ok(perm)))
}

pub async fn respond_sharing(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Path(sharing_id): Path<Uuid>,
    Json(req): Json<RespondSharingReq>,
) -> Result<ApiResponse<()>, AppError> {
    UserService::respond_sharing(&db, user_id, sharing_id, req.accept).await?;
    Ok(ApiResponse::message("Sharing request updated"))
}

pub async fn update_sharing(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Path(sharing_id): Path<Uuid>,
    Json(req): Json<UpdateSharingReq>,
) -> Result<Json<ApiResponse<common::models::SharingPermission>>, AppError> {
    let perm = UserService::update_sharing(&db, user_id, sharing_id, &req).await?;
    Ok(Json(ApiResponse::ok(perm)))
}

pub async fn delete_sharing(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Path(sharing_id): Path<Uuid>,
) -> Result<ApiResponse<()>, AppError> {
    UserService::delete_sharing(&db, user_id, sharing_id).await?;
    Ok(ApiResponse::message("Sharing permission deleted"))
}

pub async fn list_sharing(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
) -> Result<Json<ApiResponse<Vec<SharingInfo>>>, AppError> {
    let sharing = UserService::list_sharing(&db, user_id).await?;
    Ok(Json(ApiResponse::ok(sharing)))
}

/// 无需登录：Web/App 初始化高德地图前拉取 Key / 安全密钥。
pub async fn get_map_config(
    State(db): State<sqlx::PgPool>,
) -> Result<Json<ApiResponse<MapPublicConfig>>, AppError> {
    let cfg = UserService::get_map_config(&db).await?;
    Ok(Json(ApiResponse::ok(cfg)))
}
