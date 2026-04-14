/** 与 Web/mobile 一致：接口返回相对路径时拼成可访问 URL（与 HttpClient BASE 同源） */
const API_BASE = 'http://localhost:8080/api/v1';

export function resolveMediaUrl(path: string | undefined): string {
  if (!path || path.trim().length === 0) {
    return '';
  }
  const t = path.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) {
    return t;
  }
  const base = API_BASE.endsWith('/') ? API_BASE : API_BASE + '/';
  const rel = t.startsWith('/') ? t.substring(1) : t;
  return base + rel;
}
