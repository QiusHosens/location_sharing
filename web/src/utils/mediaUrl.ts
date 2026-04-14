/** 与 App 一致：接口返回 `avatars/{user_id}` 相对路径，拼成当前站点可访问 URL */
export function resolveMediaUrl(path: string | null | undefined): string | undefined {
  if (!path?.trim()) return undefined;
  const t = path.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  const basePath = '/api/v1/';
  return new URL(t, `${window.location.origin}${basePath}`).toString();
}
