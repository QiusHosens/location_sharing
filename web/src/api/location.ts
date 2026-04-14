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

/** 指定日期的轨迹分段汇总（UTC 日、每 2 小时一段），date: YYYY-MM-DD */
export async function getTrajectoryDaySummary(date: string) {
  const { data } = await api.get('/trajectory/day-summary', { params: { date } });
  return data.data as {
    date: string;
    users: Array<{
      user_id: string;
      phone: string;
      nickname?: string;
      segments: Array<{ start_time: string; end_time: string; point_count: number }>;
    }>;
  };
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
