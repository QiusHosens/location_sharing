import axios, { AxiosError, InternalAxiosRequestConfig } from 'axios';
import { useAuthStore } from '@/store/auth';

const api = axios.create({
  baseURL: '/api/v1',
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
});

/** 不带拦截器，仅用于 /auth/refresh，避免递归 */
const rawApi = axios.create({
  baseURL: '/api/v1',
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
});

let refreshPromise: Promise<void> | null = null;

async function refreshAccessToken(): Promise<void> {
  if (refreshPromise) return refreshPromise;

  refreshPromise = (async () => {
    const rt = localStorage.getItem('refresh_token');
    if (!rt) throw new Error('no refresh_token');

    const { data } = await rawApi.post<{
      data?: { access_token: string; refresh_token: string; user_id: string };
    }>('/auth/refresh', { refresh_token: rt });

    const tok = data?.data;
    if (!tok?.access_token || !tok?.refresh_token) throw new Error('invalid refresh response');

    const prev = useAuthStore.getState();
    useAuthStore.getState().setAuth(
      tok.access_token,
      tok.refresh_token,
      String(tok.user_id ?? prev.userId ?? ''),
      prev.phone ?? undefined
    );
  })().finally(() => {
    refreshPromise = null;
  });

  return refreshPromise;
}

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) config.headers.Authorization = `Bearer ${token}`;
  if (config.data instanceof FormData) {
    delete (config.headers as Record<string, unknown>)['Content-Type'];
  }
  return config;
});

api.interceptors.response.use(
  (res) => res,
  async (err: AxiosError) => {
    const status = err.response?.status;
    const config = err.config as (InternalAxiosRequestConfig & { _retry?: boolean }) | undefined;
    if (!config || status !== 401) return Promise.reject(err);

    const url = config.url ?? '';

    if (url.includes('/auth/login') || url.includes('/auth/register')) {
      return Promise.reject(err);
    }

    if (url.includes('/auth/refresh')) {
      useAuthStore.getState().logout();
      window.location.href = '/login';
      return Promise.reject(err);
    }

    if (config._retry) {
      useAuthStore.getState().logout();
      window.location.href = '/login';
      return Promise.reject(err);
    }

    try {
      await refreshAccessToken();
      config._retry = true;
      config.headers = config.headers ?? {};
      const t = useAuthStore.getState().token;
      if (t) config.headers.Authorization = `Bearer ${t}`;
      return api(config);
    } catch {
      useAuthStore.getState().logout();
      window.location.href = '/login';
      return Promise.reject(err);
    }
  }
);

export default api;
