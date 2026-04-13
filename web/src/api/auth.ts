import api from './client';

export async function sendCode(phone: string) {
  const { data } = await api.post('/auth/send-code', { phone });
  return data;
}

export async function verifyCode(phone: string, code: string) {
  const { data } = await api.post('/auth/verify-code', { phone, code });
  return data.data as { access_token: string; refresh_token: string; user_id: string; is_new_user: boolean; expires_in: number };
}

export async function refreshToken(refresh_token: string) {
  const { data } = await api.post('/auth/refresh', { refresh_token });
  return data.data;
}
