import api from './client';

export async function getProfile() {
  const { data } = await api.get('/users/profile');
  return data.data;
}

export async function updateProfile(params: { nickname?: string; avatar_url?: string }) {
  const { data } = await api.put('/users/profile', params);
  return data.data;
}

/** multipart 字段名 `file`，与移动端一致 */
export async function uploadAvatar(file: File) {
  const form = new FormData();
  form.append('file', file);
  const { data } = await api.post('/users/profile/avatar', form);
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

export async function getFamilyInvitations() {
  const { data } = await api.get('/groups/invitations');
  return data.data as any[];
}

export async function respondFamilyInvitation(invitationId: string, accept: boolean) {
  await api.put(`/groups/invitations/${invitationId}`, { accept });
}

export async function removeMember(groupId: string, memberId: string) {
  await api.delete(`/groups/${groupId}/members/${memberId}`);
}

export async function getSharing() {
  const { data } = await api.get('/sharing');
  return data.data;
}

export async function requestSharing(phone: string) {
  const { data } = await api.post('/sharing', { phone: phone.trim() });
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

/** 与同家庭成员之间的位置共享开关（owner=当前用户，viewer=对方） */
export async function setSharingPeer(viewerId: string, enabled: boolean) {
  await api.put(`/sharing/peer/${viewerId}`, { enabled });
}
