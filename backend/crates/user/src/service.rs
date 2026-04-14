use chrono::{DateTime, NaiveTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use common::error::AppError;
use common::models::{FamilyGroup, FamilyInvitation, FamilyMember, SharingPermission, User};
use notification::dto::CreateNotificationReq;
use notification::NotificationService;
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

    pub async fn get_user_by_phone(db: &PgPool, phone: &str) -> Result<User, AppError> {
        sqlx::query_as::<_, User>("SELECT * FROM users WHERE phone = $1")
            .bind(phone.trim())
            .fetch_optional(db)
            .await?
            .ok_or_else(|| AppError::NotFound("User not found with this phone".into()))
    }

    /// 向手机号对应用户发送家庭组邀请（需对方在通知中心同意后才加入）
    pub async fn invite_member(db: &PgPool, user_id: Uuid, group_id: Uuid, phone: &str) -> Result<(), AppError> {
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

        let group = sqlx::query_as::<_, FamilyGroup>("SELECT * FROM family_groups WHERE id = $1")
            .bind(group_id)
            .fetch_optional(db)
            .await?
            .ok_or_else(|| AppError::NotFound("Group not found".into()))?;

        let target = Self::get_user_by_phone(db, phone).await?;

        if target.id == user_id {
            return Err(AppError::BadRequest("Cannot invite yourself".into()));
        }

        let already: Option<(Uuid,)> = sqlx::query_as(
            "SELECT user_id FROM family_members WHERE group_id = $1 AND user_id = $2",
        )
        .bind(group_id)
        .bind(target.id)
        .fetch_optional(db)
        .await?;

        if already.is_some() {
            return Err(AppError::Conflict("User already in this group".into()));
        }

        let pending: Option<(Uuid,)> = sqlx::query_as(
            "SELECT id FROM family_invitations WHERE group_id = $1 AND invitee_id = $2 AND status = 'pending'",
        )
        .bind(group_id)
        .bind(target.id)
        .fetch_optional(db)
        .await?;

        if pending.is_some() {
            return Err(AppError::Conflict("Invitation already pending for this user".into()));
        }

        let inv = sqlx::query_as::<_, FamilyInvitation>(
            "INSERT INTO family_invitations (group_id, inviter_id, invitee_id, status) VALUES ($1, $2, $3, 'pending') RETURNING *",
        )
        .bind(group_id)
        .bind(user_id)
        .bind(target.id)
        .fetch_one(db)
        .await
        .map_err(|e| {
            if let sqlx::Error::Database(ref d) = e {
                if d.code().as_deref() == Some("23505") {
                    return AppError::Conflict("Invitation already pending for this user".into());
                }
            }
            e.into()
        })?;

        let inviter = Self::get_profile(db, user_id).await?;
        let inviter_label = inviter
            .nickname
            .clone()
            .unwrap_or_else(|| inviter.phone.clone());

        let title = "家庭组邀请".to_string();
        let body = format!(
            "{} 邀请你加入家庭组「{}」",
            inviter_label, group.name
        );
        let data = serde_json::json!({
            "invitation_id": inv.id,
            "group_id": group.id,
            "group_name": group.name,
            "type": "family_invite",
        });

        NotificationService::create(
            db,
            &CreateNotificationReq {
                user_id: target.id,
                r#type: "family_invite".to_string(),
                title: Some(title),
                body: Some(body),
                data: Some(data),
            },
        )
        .await?;

        Ok(())
    }

    pub async fn list_pending_family_invitations(
        db: &PgPool,
        invitee_id: Uuid,
    ) -> Result<Vec<FamilyInvitationInfo>, AppError> {
        let rows = sqlx::query_as::<_, (Uuid, Uuid, String, Uuid, String, Option<String>, DateTime<Utc>)>(
            "SELECT fi.id, fi.group_id, fg.name, fi.inviter_id, u.phone, u.nickname, fi.created_at
             FROM family_invitations fi
             INNER JOIN family_groups fg ON fg.id = fi.group_id
             INNER JOIN users u ON u.id = fi.inviter_id
             WHERE fi.invitee_id = $1 AND fi.status = 'pending'
             ORDER BY fi.created_at DESC",
        )
        .bind(invitee_id)
        .fetch_all(db)
        .await?;

        Ok(rows
            .into_iter()
            .map(
                |(id, group_id, group_name, inviter_id, inviter_phone, inviter_nickname, created_at)| {
                    FamilyInvitationInfo {
                        id,
                        group_id,
                        group_name,
                        inviter_id,
                        inviter_phone,
                        inviter_nickname,
                        created_at,
                    }
                },
            )
            .collect())
    }

    pub async fn respond_family_invitation(
        db: &PgPool,
        user_id: Uuid,
        invitation_id: Uuid,
        accept: bool,
    ) -> Result<(), AppError> {
        let inv = sqlx::query_as::<_, FamilyInvitation>(
            "SELECT * FROM family_invitations WHERE id = $1 AND invitee_id = $2 AND status = 'pending'",
        )
        .bind(invitation_id)
        .bind(user_id)
        .fetch_optional(db)
        .await?
        .ok_or_else(|| AppError::NotFound("Invitation not found".into()))?;

        let mut tx = db.begin().await?;

        if accept {
            sqlx::query(
                "INSERT INTO family_members (group_id, user_id, role) VALUES ($1, $2, 'member') ON CONFLICT DO NOTHING",
            )
            .bind(inv.group_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        }

        let status = if accept { "accepted" } else { "rejected" };
        sqlx::query(
            "UPDATE family_invitations SET status = $1, updated_at = NOW() WHERE id = $2",
        )
        .bind(status)
        .bind(invitation_id)
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;
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
