use chrono::NaiveTime;
use sqlx::PgPool;
use uuid::Uuid;

use common::error::AppError;
use common::models::{FamilyGroup, FamilyMember, SharingPermission, User};
use std::collections::HashMap;

use crate::dto::*;

pub struct UserService;

impl UserService {
    pub async fn get_profile(db: &PgPool, user_id: Uuid) -> Result<User, AppError> {
        sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
            .bind(user_id)
            .fetch_optional(db)
            .await?
            .ok_or_else(|| AppError::NotFound("User not found".into()))
    }

    pub async fn update_profile(
        db: &PgPool,
        user_id: Uuid,
        req: &UpdateProfileReq,
    ) -> Result<User, AppError> {
        sqlx::query_as::<_, User>(
            "UPDATE users SET nickname = COALESCE($2, nickname), avatar_url = COALESCE($3, avatar_url), updated_at = NOW() WHERE id = $1 RETURNING *"
        )
        .bind(user_id)
        .bind(&req.nickname)
        .bind(&req.avatar_url)
        .fetch_one(db)
        .await
        .map_err(Into::into)
    }

    // ---- Family Groups ----

    pub async fn create_group(db: &PgPool, user_id: Uuid, name: &str) -> Result<FamilyGroup, AppError> {
        let group = sqlx::query_as::<_, FamilyGroup>(
            "INSERT INTO family_groups (name, creator_id) VALUES ($1, $2) RETURNING *"
        )
        .bind(name)
        .bind(user_id)
        .fetch_one(db)
        .await?;

        sqlx::query("INSERT INTO family_members (group_id, user_id, role) VALUES ($1, $2, 'owner')")
            .bind(group.id)
            .bind(user_id)
            .execute(db)
            .await?;

        Ok(group)
    }

    pub async fn list_groups(db: &PgPool, user_id: Uuid) -> Result<Vec<GroupWithMembers>, AppError> {
        let groups = sqlx::query_as::<_, FamilyGroup>(
            "SELECT fg.* FROM family_groups fg INNER JOIN family_members fm ON fg.id = fm.group_id WHERE fm.user_id = $1 ORDER BY fg.created_at DESC"
        )
        .bind(user_id)
        .fetch_all(db)
        .await?;

        let mut result = Vec::new();
        for group in groups {
            let members = sqlx::query_as::<_, (Uuid, String, Option<String>, String)>(
                "SELECT u.id, u.phone, u.nickname, fm.role FROM family_members fm INNER JOIN users u ON u.id = fm.user_id WHERE fm.group_id = $1"
            )
            .bind(group.id)
            .fetch_all(db)
            .await?;

            let member_infos = members.into_iter().map(|(user_id, phone, nickname, role)| {
                GroupMemberInfo { user_id, phone, nickname, role }
            }).collect();

            result.push(GroupWithMembers {
                id: group.id,
                name: group.name,
                creator_id: group.creator_id,
                members: member_infos,
            });
        }

        Ok(result)
    }

    pub async fn delete_group(db: &PgPool, user_id: Uuid, group_id: Uuid) -> Result<(), AppError> {
        let group = sqlx::query_as::<_, FamilyGroup>(
            "SELECT * FROM family_groups WHERE id = $1"
        )
        .bind(group_id)
        .fetch_optional(db)
        .await?
        .ok_or_else(|| AppError::NotFound("Group not found".into()))?;

        if group.creator_id != user_id {
            return Err(AppError::Forbidden);
        }

        sqlx::query("DELETE FROM family_groups WHERE id = $1")
            .bind(group_id)
            .execute(db)
            .await?;

        Ok(())
    }

    pub async fn add_member(db: &PgPool, user_id: Uuid, group_id: Uuid, phone: &str) -> Result<(), AppError> {
        let member = sqlx::query_as::<_, FamilyMember>(
            "SELECT * FROM family_members WHERE group_id = $1 AND user_id = $2"
        )
        .bind(group_id)
        .bind(user_id)
        .fetch_optional(db)
        .await?;

        if member.is_none() {
            return Err(AppError::Forbidden);
        }

        let target = sqlx::query_as::<_, User>("SELECT * FROM users WHERE phone = $1")
            .bind(phone)
            .fetch_optional(db)
            .await?
            .ok_or_else(|| AppError::NotFound("User not found with this phone".into()))?;

        sqlx::query(
            "INSERT INTO family_members (group_id, user_id, role) VALUES ($1, $2, 'member') ON CONFLICT DO NOTHING"
        )
        .bind(group_id)
        .bind(target.id)
        .execute(db)
        .await?;

        Ok(())
    }

    pub async fn remove_member(db: &PgPool, user_id: Uuid, group_id: Uuid, member_id: Uuid) -> Result<(), AppError> {
        let group = sqlx::query_as::<_, FamilyGroup>("SELECT * FROM family_groups WHERE id = $1")
            .bind(group_id)
            .fetch_optional(db)
            .await?
            .ok_or_else(|| AppError::NotFound("Group not found".into()))?;

        if group.creator_id != user_id && member_id != user_id {
            return Err(AppError::Forbidden);
        }

        sqlx::query("DELETE FROM family_members WHERE group_id = $1 AND user_id = $2")
            .bind(group_id)
            .bind(member_id)
            .execute(db)
            .await?;

        Ok(())
    }

    // ---- Sharing Permissions ----

    pub async fn request_sharing(db: &PgPool, owner_id: Uuid, viewer_id: Uuid) -> Result<SharingPermission, AppError> {
        if owner_id == viewer_id {
            return Err(AppError::BadRequest("Cannot share with yourself".into()));
        }

        let perm = sqlx::query_as::<_, SharingPermission>(
            "INSERT INTO sharing_permissions (owner_id, viewer_id, status) VALUES ($1, $2, 'pending') ON CONFLICT (owner_id, viewer_id) DO UPDATE SET status = 'pending', updated_at = NOW() RETURNING *"
        )
        .bind(owner_id)
        .bind(viewer_id)
        .fetch_one(db)
        .await?;

        Ok(perm)
    }

    pub async fn respond_sharing(db: &PgPool, user_id: Uuid, sharing_id: Uuid, accept: bool) -> Result<(), AppError> {
        let status = if accept { "accepted" } else { "rejected" };

        let result = sqlx::query(
            "UPDATE sharing_permissions SET status = $1, updated_at = NOW() WHERE id = $2 AND owner_id = $3 AND status = 'pending'"
        )
        .bind(status)
        .bind(sharing_id)
        .bind(user_id)
        .execute(db)
        .await?;

        if result.rows_affected() == 0 {
            return Err(AppError::NotFound("Sharing request not found".into()));
        }

        Ok(())
    }

    pub async fn update_sharing(
        db: &PgPool,
        user_id: Uuid,
        sharing_id: Uuid,
        req: &UpdateSharingReq,
    ) -> Result<SharingPermission, AppError> {
        sqlx::query_as::<_, SharingPermission>(
            "UPDATE sharing_permissions SET is_paused = COALESCE($2, is_paused), visible_start = COALESCE($3, visible_start), visible_end = COALESCE($4, visible_end), updated_at = NOW() WHERE id = $1 AND owner_id = $5 RETURNING *"
        )
        .bind(sharing_id)
        .bind(req.is_paused)
        .bind(req.visible_start)
        .bind(req.visible_end)
        .bind(user_id)
        .fetch_optional(db)
        .await?
        .ok_or_else(|| AppError::NotFound("Sharing permission not found".into()))
    }

    pub async fn delete_sharing(db: &PgPool, user_id: Uuid, sharing_id: Uuid) -> Result<(), AppError> {
        let result = sqlx::query(
            "DELETE FROM sharing_permissions WHERE id = $1 AND (owner_id = $2 OR viewer_id = $2)"
        )
        .bind(sharing_id)
        .bind(user_id)
        .execute(db)
        .await?;

        if result.rows_affected() == 0 {
            return Err(AppError::NotFound("Sharing permission not found".into()));
        }

        Ok(())
    }

    pub async fn list_sharing(db: &PgPool, user_id: Uuid) -> Result<Vec<SharingInfo>, AppError> {
        let rows = sqlx::query_as::<_, (Uuid, Uuid, Uuid, String, Option<NaiveTime>, Option<NaiveTime>, bool, Option<String>, String)>(
            "SELECT sp.id, sp.owner_id, sp.viewer_id, sp.status, sp.visible_start, sp.visible_end, sp.is_paused, u.nickname, u.phone FROM sharing_permissions sp INNER JOIN users u ON u.id = CASE WHEN sp.owner_id = $1 THEN sp.viewer_id ELSE sp.owner_id END WHERE sp.owner_id = $1 OR sp.viewer_id = $1 ORDER BY sp.created_at DESC"
        )
        .bind(user_id)
        .fetch_all(db)
        .await?;

        Ok(rows.into_iter().map(|(id, owner_id, viewer_id, status, visible_start, visible_end, is_paused, peer_nickname, peer_phone)| {
            SharingInfo { id, owner_id, viewer_id, status, visible_start, visible_end, is_paused, peer_nickname, peer_phone }
        }).collect())
    }

    /// 高德地图公开配置（Key 等），供 Web/App 初始化地图前拉取。
    pub async fn get_map_config(db: &PgPool) -> Result<MapPublicConfig, AppError> {
        let rows: Vec<(String, serde_json::Value)> = sqlx::query_as(
            "SELECT key, value FROM system_configs WHERE key IN ('amap_web_key', 'amap_web_secret', 'amap_android_key', 'amap_ios_key')",
        )
        .fetch_all(db)
        .await?;

        let mut m = HashMap::new();
        for (k, v) in rows {
            m.insert(k, v);
        }

        fn take_str(m: &HashMap<String, serde_json::Value>, key: &str) -> String {
            m.get(key)
                .map(|v| match v {
                    serde_json::Value::String(s) => s.clone(),
                    serde_json::Value::Null => String::new(),
                    x => x.as_str().unwrap_or("").to_string(),
                })
                .unwrap_or_default()
        }

        Ok(MapPublicConfig {
            web_key: take_str(&m, "amap_web_key"),
            web_security_secret: take_str(&m, "amap_web_secret"),
            android_key: take_str(&m, "amap_android_key"),
            ios_key: take_str(&m, "amap_ios_key"),
        })
    }
}
