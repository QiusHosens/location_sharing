-- 高德地图 Key（管理后台可改）；客户端通过 GET /api/v1/config/map 拉取
INSERT INTO system_configs (key, value, description) VALUES
    ('amap_web_key', to_jsonb(''::text), '高德 Web(JS) API Key'),
    ('amap_web_secret', to_jsonb(''::text), '高德 Web 安全密钥 securityJsCode（JS API 2.0）'),
    ('amap_android_key', to_jsonb(''::text), '高德 Android Key'),
    ('amap_ios_key', to_jsonb(''::text), '高德 iOS Key')
ON CONFLICT (key) DO NOTHING;
