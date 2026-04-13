-- 用户端改为手机号+密码登录：bcrypt 存储
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;

COMMENT ON COLUMN users.password_hash IS 'bcrypt(password)，未注册成功前可为 NULL';
