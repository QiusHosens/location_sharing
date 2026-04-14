-- 定位记录增加电量（0–100，与客户端约定）
ALTER TABLE location_records ADD COLUMN IF NOT EXISTS battery_level SMALLINT;
