-- Location Sharing System - Initial Schema

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==================== Admins ====================
CREATE TABLE IF NOT EXISTS admins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(64) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    nickname VARCHAR(64),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==================== Users ====================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) NOT NULL UNIQUE,
    nickname VARCHAR(64),
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_phone ON users(phone);

-- ==================== Family Groups ====================
CREATE TABLE IF NOT EXISTS family_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_family_groups_creator ON family_groups(creator_id);

-- ==================== Family Members ====================
CREATE TABLE IF NOT EXISTS family_members (
    group_id UUID NOT NULL REFERENCES family_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, user_id)
);

CREATE INDEX idx_family_members_user ON family_members(user_id);

-- ==================== Sharing Permissions ====================
CREATE TABLE IF NOT EXISTS sharing_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    viewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    visible_start TIME,
    visible_end TIME,
    is_paused BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(owner_id, viewer_id)
);

CREATE INDEX idx_sharing_owner ON sharing_permissions(owner_id);
CREATE INDEX idx_sharing_viewer ON sharing_permissions(viewer_id);

-- ==================== Location Records ====================
CREATE TABLE IF NOT EXISTS location_records (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    longitude DOUBLE PRECISION NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    altitude DOUBLE PRECISION,
    speed REAL,
    bearing REAL,
    accuracy REAL,
    source VARCHAR(20),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_location_user_time ON location_records(user_id, recorded_at DESC);

-- ==================== Notifications ====================
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(200),
    body TEXT,
    data JSONB,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);

-- ==================== System Configs ====================
CREATE TABLE IF NOT EXISTS system_configs (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL DEFAULT '{}',
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==================== Call Logs ====================
CREATE TABLE IF NOT EXISTS call_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    caller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    callee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'initiated',
    duration_seconds INTEGER,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ
);

CREATE INDEX idx_call_logs_caller ON call_logs(caller_id, started_at DESC);
CREATE INDEX idx_call_logs_callee ON call_logs(callee_id, started_at DESC);

-- ==================== Default Data ====================

-- Default admin user（明文 admin123；前端传 MD5 hex；库存 bcrypt(MD5(明文))）
INSERT INTO admins (username, password_hash, nickname, is_active)
VALUES (
    'admin',
    '$2b$12$0Y/Cs/YllONoQgMH3IgOPOh3j5z7qgGeVQdujh25kTxBf4K/SU/em',
    'System Admin',
    TRUE
) ON CONFLICT (username) DO NOTHING;

-- Default system configs
INSERT INTO system_configs (key, value, description) VALUES
    ('sms_provider', '"aliyun"', 'SMS service provider: aliyun or tencent'),
    ('sms_daily_limit', '10', 'Maximum SMS verification codes per phone per day'),
    ('sms_code_ttl', '300', 'SMS verification code TTL in seconds'),
    ('location_update_interval', '10', 'Location update interval in seconds'),
    ('trajectory_retention_days', '30', 'How many days to retain trajectory data'),
    ('max_family_members', '20', 'Maximum members per family group')
ON CONFLICT (key) DO NOTHING;
