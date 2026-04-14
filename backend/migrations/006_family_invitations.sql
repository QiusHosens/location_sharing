-- 家庭组邀请：待对方同意后才写入 family_members

CREATE TABLE IF NOT EXISTS family_invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES family_groups(id) ON DELETE CASCADE,
    inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT family_invite_no_self CHECK (inviter_id <> invitee_id)
);

CREATE UNIQUE INDEX idx_family_inv_one_pending
    ON family_invitations (group_id, invitee_id)
    WHERE (status = 'pending');

CREATE INDEX idx_family_inv_invitee ON family_invitations (invitee_id, status);
CREATE INDEX idx_family_inv_group ON family_invitations (group_id);
