import api from './client';

export async function register(phone: string, password: string) {
  const { data } = await api.post('/auth/register', { phone, password });
  return data.data as { access_token: string; refresh_token: string; user_id: string; is_new_user: boolean; expires_in: number };
}

export async function login(phone: string, password: string) {
  const { data } = await api.post('/auth/login', { phone, password });
  return data.data as { access_token: string; refresh_token: string; user_id: string; is_new_user: boolean; expires_in: number };
}

export async function refreshToken(refresh_token: string) {
  const { data } = await api.post('/auth/refresh', { refresh_token });
  return data.data;
}
