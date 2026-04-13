import api from './client';

export async function getProfile() {
  const { data } = await api.get('/users/profile');
  return data.data;
}

export async function updateProfile(params: { nickname?: string; avatar_url?: string }) {
  const { data } = await api.put('/users/profile', params);
  return data.data;
}

export async function getGroups() {
  const { data } = await api.get('/groups');
  return data.data;
}

export async function createGroup(name: string) {
  const { data } = await api.post('/groups', { name });
  return data.data;
}

export async function deleteGroup(id: string) {
  await api.delete(`/groups/${id}`);
}

export async function addMember(groupId: string, phone: string) {
  await api.post(`/groups/${groupId}/members`, { phone });
}

export async function removeMember(groupId: string, memberId: string) {
  await api.delete(`/groups/${groupId}/members/${memberId}`);
}

export async function getSharing() {
  const { data } = await api.get('/sharing');
  return data.data;
}

export async function requestSharing(targetUserId: string) {
  const { data } = await api.post('/sharing', { target_user_id: targetUserId });
  return data.data;
}

export async function respondSharing(id: string, accept: boolean) {
  await api.put(`/sharing/${id}/respond`, { accept });
}

export async function updateSharing(id: string, params: { is_paused?: boolean; visible_start?: string; visible_end?: string }) {
  const { data } = await api.put(`/sharing/${id}`, params);
  return data.data;
}

export async function deleteSharing(id: string) {
  await api.delete(`/sharing/${id}`);
}
