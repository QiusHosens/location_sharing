import axios from 'axios';
import { useAuthStore } from '@/store/auth';

const client = axios.create({
  baseURL: '/api/v1/admin',
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
});

client.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

client.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      useAuthStore.getState().logout();
      window.location.href = '/login';
    }
    return Promise.reject(err);
  }
);

export default client;

export async function adminLogin(username: string, password: string) {
  const { data } = await client.post('/login', { username, password });
  return data.data as { access_token: string; admin_id: string; username: string };
}

export async function getStats() {
  const { data } = await client.get('/stats');
  return data.data as { total_users: number; total_groups: number; active_sharing: number; today_locations: number };
}

export async function getUsers(params: { page?: number; page_size?: number; phone?: string; nickname?: string }) {
  const { data } = await client.get('/users', { params });
  return data.data as { items: any[]; total: number };
}

export async function getConfigs() {
  const { data } = await client.get('/configs');
  return data.data as Array<{ key: string; value: any; description: string | null; updated_at: string }>;
}

export async function updateConfig(key: string, value: any, description?: string) {
  const { data } = await client.put(`/configs/${key}`, { value, description });
  return data.data;
}
