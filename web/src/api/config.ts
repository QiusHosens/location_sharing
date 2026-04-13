/**
 * 公开配置，不依赖登录态（避免未带 token 时拉取失败）
 */
export interface MapConfig {
  web_key: string;
  web_security_secret: string;
  android_key: string;
  ios_key: string;
}

export async function getMapConfig(): Promise<MapConfig> {
  const res = await fetch('/api/v1/config/map', { headers: { Accept: 'application/json' } });
  if (!res.ok) throw new Error(`map config ${res.status}`);
  const body = await res.json();
  return body.data as MapConfig;
}
