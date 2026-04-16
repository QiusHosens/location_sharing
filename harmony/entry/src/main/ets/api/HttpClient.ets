import { http } from '@kit.NetworkKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const BASE_URL = 'http://www.synerunify.com:40808/api/v1';

function shouldRefreshOn401(path: string): boolean {
  return !path.includes('/auth/login') && !path.includes('/auth/register') && !path.includes('/auth/refresh');
}

export class HttpClient {
  private static ctx: common.Context | null = null;
  private static accessToken: string | null = null;
  private static refreshToken: string | null = null;

  static setContext(context: common.Context): void {
    HttpClient.ctx = context;
  }

  static setSession(access: string, refresh: string): void {
    HttpClient.accessToken = access;
    HttpClient.refreshToken = refresh;
  }

  static clearSession(): void {
    HttpClient.accessToken = null;
    HttpClient.refreshToken = null;
  }

  /** 从 preferences 读入内存（启动后调用） */
  static async loadTokensFromPrefs(): Promise<void> {
    if (!HttpClient.ctx) {
      return;
    }
    const store = await preferences.getPreferences(HttpClient.ctx, 'auth');
    HttpClient.accessToken = (await store.get('token', '')) as string;
    HttpClient.refreshToken = (await store.get('refresh_token', '')) as string;
  }

  static async persistSession(): Promise<void> {
    if (!HttpClient.ctx) {
      return;
    }
    const store = await preferences.getPreferences(HttpClient.ctx, 'auth');
    if (HttpClient.accessToken) {
      await store.put('token', HttpClient.accessToken);
    }
    if (HttpClient.refreshToken) {
      await store.put('refresh_token', HttpClient.refreshToken);
    }
    await store.flush();
  }

  private static async tryRefresh(): Promise<boolean> {
    if (!HttpClient.refreshToken || HttpClient.refreshToken.length === 0) {
      return false;
    }
    const r = http.createHttp();
    try {
      const res = await r.request(`${BASE_URL}/auth/refresh`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ refresh_token: HttpClient.refreshToken })
      });
      const code = res.responseCode;
      if (code !== 200) {
        return false;
      }
      const json = JSON.parse(res.result as string) as Record<string, Object>;
      const data = json['data'] as Record<string, string>;
      if (!data || !data['access_token'] || !data['refresh_token']) {
        return false;
      }
      HttpClient.setSession(data['access_token'], data['refresh_token']);
      await HttpClient.persistSession();
      return true;
    } catch {
      return false;
    } finally {
      r.destroy();
    }
  }

  private static getHeaders(): Record<string, string> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (HttpClient.accessToken) {
      headers['Authorization'] = 'Bearer ' + HttpClient.accessToken;
    }
    return headers;
  }

  private static async requestWith401Retry(
    method: http.RequestMethod,
    path: string,
    body: string | undefined,
    allowRefresh: boolean
  ): Promise<object> {
    const url = BASE_URL + path;
    let attempt = 0;
    while (attempt < 2) {
      const req = http.createHttp();
      try {
        const res = await req.request(url, {
          method: method,
          header: HttpClient.getHeaders(),
          extraData: body,
        });
        const code = res.responseCode;
        if (code === 401 && allowRefresh && attempt === 0 && shouldRefreshOn401(path)) {
          const ok = await HttpClient.tryRefresh();
          if (ok) {
            attempt++;
            continue;
          }
          throw new Error('Unauthorized');
        }
        if (code < 200 || code >= 300) {
          throw new Error(`HTTP ${code}`);
        }
        return JSON.parse(res.result as string) as object;
      } finally {
        req.destroy();
      }
    }
    throw new Error('Unauthorized');
  }

  static async get(path: string, params?: Record<string, string>): Promise<object> {
    let full = path;
    if (params) {
      const query = Object.keys(params).map(k => k + '=' + encodeURIComponent(params[k])).join('&');
      full += '?' + query;
    }
    return HttpClient.requestWith401Retry(http.RequestMethod.GET, full, undefined, true);
  }

  static async post(path: string, body?: object): Promise<object> {
    const extra = body ? JSON.stringify(body) : undefined;
    return HttpClient.requestWith401Retry(http.RequestMethod.POST, path, extra, true);
  }

  static async put(path: string, body?: object): Promise<object> {
    const extra = body ? JSON.stringify(body) : undefined;
    return HttpClient.requestWith401Retry(http.RequestMethod.PUT, path, extra, true);
  }

  static async del(path: string): Promise<object> {
    return HttpClient.requestWith401Retry(http.RequestMethod.DELETE, path, undefined, true);
  }
}
