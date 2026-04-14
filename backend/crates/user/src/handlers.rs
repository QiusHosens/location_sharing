use std::path::{Path as FsPath, PathBuf};

use axum::{
    body::Body,
    extract::{Multipart, Path, State},
    http::{header, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use uuid::Uuid;
use validator::Validate;

use auth::AuthUser;
use common::error::AppError;
use common::response::ApiResponse;
use crate::dto::*;
use crate::service::UserService;

const MAX_AVATAR_BYTES: usize = 2 * 1024 * 1024;

fn upload_dir_path() -> PathBuf {
    std::env::var("UPLOAD_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("./data/uploads"))
}

fn ext_from_mime_and_filename(mime: Option<&str>, filename: Option<&str>) -> Option<&'static str> {
    if let Some(m) = mime {
        let m = m.split(';').next()?.trim().to_ascii_lowercase();
        match m.as_str() {
            "image/jpeg" | "image/jpg" => return Some("jpg"),
            "image/png" => return Some("png"),
            "image/webp" => return Some("webp"),
            "image/gif" => return Some("gif"),
            _ => {}
        }
    }
    let name = filename?;
    let ext = FsPath::new(name).extension()?.to_str()?.to_ascii_lowercase();
    match ext.as_str() {
        "jpg" | "jpeg" => Some("jpg"),
        "png" => Some("png"),
        "webp" => Some("webp"),
        "gif" => Some("gif"),
        _ => None,
    }
}

fn content_type_for_ext(ext: &str) -> &'static str {
    if ext.eq_ignore_ascii_case("jpg") || ext.eq_ignore_ascii_case("jpeg") {
        return "image/jpeg";
    }
    if ext.eq_ignore_ascii_case("png") {
        return "image/png";
    }
    if ext.eq_ignore_ascii_case("webp") {
        return "image/webp";
    }
    if ext.eq_ignore_ascii_case("gif") {
        return "image/gif";
    }
    "application/octet-stream"
}

async fn remove_existing_avatar_files(upload_dir: &FsPath, user_id: Uuid) -> Result<(), std::io::Error> {
    for ext in ["jpg", "jpeg", "png", "webp", "gif"] {
        let p = upload_dir.join(format!("{user_id}.{ext}"));
        if tokio::fs::metadata(&p).await.is_ok() {
            tokio::fs::remove_file(&p).await?;
        }
    }
    Ok(())
}

async fn find_avatar_path(upload_dir: &FsPath, user_id: Uuid) -> Result<Option<PathBuf>, std::io::Error> {
    for ext in ["jpg", "jpeg", "png", "webp", "gif"] {
        let p = upload_dir.join(format!("{user_id}.{ext}"));
        if tokio::fs::metadata(&p).await.is_ok() {
            return Ok(Some(p));
        }
    }
    Ok(None)
}

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

pub async fn invite_member(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Path(group_id): Path<Uuid>,
    Json(req): Json<InviteMemberReq>,
) -> Result<ApiResponse<()>, AppError> {
    UserService::invite_member(&db, user_id, group_id, &req.phone).await?;
    Ok(ApiResponse::message("Invitation sent"))
}

pub async fn list_family_invitations(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
) -> Result<Json<ApiResponse<Vec<FamilyInvitationInfo>>>, AppError> {
    let items = UserService::list_pending_family_invitations(&db, user_id).await?;
    Ok(Json(ApiResponse::ok(items)))
}

pub async fn respond_family_invitation(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Path(invitation_id): Path<Uuid>,
    Json(req): Json<RespondFamilyInviteReq>,
) -> Result<ApiResponse<()>, AppError> {
    UserService::respond_family_invitation(&db, user_id, invitation_id, req.accept).await?;
    Ok(ApiResponse::message(if req.accept {
        "Joined group"
    } else {
        "Invitation declined"
    }))
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
    let phone = req.phone.trim();
    if phone.is_empty() {
        return Err(AppError::BadRequest("phone is required".into()));
    }
    let viewer_id = UserService::get_user_by_phone(&db, phone).await?.id;
    let perm = UserService::request_sharing(&db, user_id, viewer_id).await?;
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

/// 家庭页：向同家庭成员开启/关闭位置共享（owner=当前用户，viewer=对方）
pub async fn put_sharing_peer(
    AuthUser(owner_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    Path(viewer_id): Path<Uuid>,
    Json(req): Json<SetPeerSharingReq>,
) -> Result<ApiResponse<()>, AppError> {
    UserService::set_sharing_with_family_peer(&db, owner_id, viewer_id, req.enabled).await?;
    Ok(ApiResponse::message("Sharing updated"))
}

/// 已登录：multipart 字段名 `file`，单张图片 ≤2MB（jpeg/png/webp/gif），落盘后写入 `users.avatar_url`（相对路径 `avatars/{user_id}`）。
pub async fn upload_avatar(
    AuthUser(user_id): AuthUser,
    State(db): State<sqlx::PgPool>,
    mut multipart: Multipart,
) -> Result<Json<ApiResponse<UserProfile>>, AppError> {
    let upload_dir = upload_dir_path();
    tokio::fs::create_dir_all(&upload_dir)
        .await
        .map_err(|e| AppError::Internal(e.into()))?;

    remove_existing_avatar_files(&upload_dir, user_id)
        .await
        .map_err(|e| AppError::Internal(e.into()))?;

    let mut file_bytes: Option<Vec<u8>> = None;
    let mut ext_opt: Option<&'static str> = None;

    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|e| AppError::BadRequest(e.to_string()))?
    {
        if field.name() != Some("file") {
            continue;
        }
        let ct = field.content_type().map(|s| s.to_string());
        let fname = field.file_name().map(|s| s.to_string());
        let ext = ext_from_mime_and_filename(ct.as_deref(), fname.as_deref()).ok_or_else(|| {
            AppError::BadRequest("Unsupported image type (use jpeg, png, webp, or gif)".into())
        })?;
        let data = field
            .bytes()
            .await
            .map_err(|e| AppError::BadRequest(e.to_string()))?;
        if data.len() > MAX_AVATAR_BYTES {
            return Err(AppError::BadRequest("Image too large (max 2MB)".into()));
        }
        if data.is_empty() {
            return Err(AppError::BadRequest("Empty file".into()));
        }
        file_bytes = Some(data.to_vec());
        ext_opt = Some(ext);
        break;
    }

    let (bytes, ext) = match (file_bytes, ext_opt) {
        (Some(b), Some(e)) => (b, e),
        _ => return Err(AppError::BadRequest("Missing file field".into())),
    };

    let path = upload_dir.join(format!("{user_id}.{ext}"));
    tokio::fs::write(&path, bytes)
        .await
        .map_err(|e| AppError::Internal(e.into()))?;

    let avatar_url = format!("avatars/{user_id}");
    let req = UpdateProfileReq {
        nickname: None,
        avatar_url: Some(avatar_url),
    };
    let user = UserService::update_profile(&db, user_id, &req).await?;
    Ok(Json(ApiResponse::ok(UserProfile {
        id: user.id,
        phone: user.phone,
        nickname: user.nickname,
        avatar_url: user.avatar_url,
    })))
}

/// 无需登录：按用户 ID 读取磁盘上的头像字节（与 DB 中 `avatars/{id}` 对应）。
pub async fn get_avatar(Path(user_id): Path<Uuid>) -> impl IntoResponse {
    let upload_dir = upload_dir_path();
    let path = match find_avatar_path(&upload_dir, user_id).await {
        Ok(Some(p)) => p,
        Ok(None) => {
            return (StatusCode::NOT_FOUND, "avatar not found").into_response();
        }
        Err(e) => {
            tracing::error!("find avatar: {e}");
            return StatusCode::INTERNAL_SERVER_ERROR.into_response();
        }
    };

    let ext = path
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("");
    let ct = content_type_for_ext(ext);

    match tokio::fs::read(&path).await {
        Ok(bytes) => {
            let ct_val = match header::HeaderValue::from_str(ct) {
                Ok(v) => v,
                Err(_) => header::HeaderValue::from_static("application/octet-stream"),
            };
            let mut res = Response::new(Body::from(bytes));
            res.headers_mut().insert(header::CONTENT_TYPE, ct_val);
            res.headers_mut().insert(
                header::CACHE_CONTROL,
                header::HeaderValue::from_static("public, max-age=86400"),
            );
            res.into_response()
        }
        Err(e) => {
            tracing::error!("read avatar file: {e}");
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}

/// 无需登录：Web/App 初始化高德地图前拉取 Key / 安全密钥。
pub async fn get_map_config(
    State(db): State<sqlx::PgPool>,
) -> Result<Json<ApiResponse<MapPublicConfig>>, AppError> {
    let cfg = UserService::get_map_config(&db).await?;
    Ok(Json(ApiResponse::ok(cfg)))
}
