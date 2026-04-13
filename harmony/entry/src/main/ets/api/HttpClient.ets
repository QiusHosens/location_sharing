import { http } from '@kit.NetworkKit';

const BASE_URL = 'http://localhost:8080/api/v1';

export class HttpClient {
  private static token: string | null = null;

  static setToken(token: string): void {
    HttpClient.token = token;
  }

  static clearToken(): void {
    HttpClient.token = null;
  }

  static async get(path: string, params?: Record<string, string>): Promise<object> {
    let url = BASE_URL + path;
    if (params) {
      const query = Object.keys(params).map(k => k + '=' + encodeURIComponent(params[k])).join('&');
      url += '?' + query;
    }
    const req = http.createHttp();
    const res = await req.request(url, {
      method: http.RequestMethod.GET,
      header: HttpClient.getHeaders(),
    });
    req.destroy();
    return JSON.parse(res.result as string);
  }

  static async post(path: string, body?: object): Promise<object> {
    const req = http.createHttp();
    const res = await req.request(BASE_URL + path, {
      method: http.RequestMethod.POST,
      header: HttpClient.getHeaders(),
      extraData: body ? JSON.stringify(body) : undefined,
    });
    req.destroy();
    return JSON.parse(res.result as string);
  }

  static async put(path: string, body?: object): Promise<object> {
    const req = http.createHttp();
    const res = await req.request(BASE_URL + path, {
      method: http.RequestMethod.PUT,
      header: HttpClient.getHeaders(),
      extraData: body ? JSON.stringify(body) : undefined,
    });
    req.destroy();
    return JSON.parse(res.result as string);
  }

  static async del(path: string): Promise<object> {
    const req = http.createHttp();
    const res = await req.request(BASE_URL + path, {
      method: http.RequestMethod.DELETE,
      header: HttpClient.getHeaders(),
    });
    req.destroy();
    return JSON.parse(res.result as string);
  }

  private static getHeaders(): Record<string, string> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (HttpClient.token) {
      headers['Authorization'] = 'Bearer ' + HttpClient.token;
    }
    return headers;
  }
}
