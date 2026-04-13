import api from './client';

export async function getLatestLocation() {
  const { data } = await api.get('/location/latest');
  return data.data;
}

export async function getSharedLocation(userId: string) {
  const { data } = await api.get(`/location/shared/${userId}`);
  return data.data;
}

export async function getFamilyLocations(groupId: string) {
  const { data } = await api.get(`/location/family/${groupId}`);
  return data.data;
}

export async function getTrajectory(userId: string, startTime: string, endTime: string) {
  const { data } = await api.get('/trajectory', { params: { user_id: userId, start_time: startTime, end_time: endTime } });
  return data.data;
}

export async function getNotifications(params?: { page?: number; page_size?: number; unread_only?: boolean }) {
  const { data } = await api.get('/notifications', { params });
  return data.data;
}

export async function markRead(id: string) {
  await api.put(`/notifications/${id}/read`);
}

export async function markAllRead() {
  await api.put('/notifications/read-all');
}
