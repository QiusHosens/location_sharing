import 'package:dio/dio.dart';

import 'client.dart';

class UserApi {
  final _client = ApiClient();

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _client.get('/users/profile');
    return res['data'];
  }

  Future<void> updateProfile({String? nickname, String? avatarUrl}) async {
    await _client.put('/users/profile', data: {
      if (nickname != null) 'nickname': nickname,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
  }

  /// multipart 字段名 `file`，成功后返回与 [getProfile] 相同结构的 `data`。
  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    final name = filePath.split(RegExp(r'[/\\]')).last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: name),
    });
    final res = await _client.postMultipart('/users/profile/avatar', form);
    final d = res['data'];
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
    return {};
  }

  Future<List<dynamic>> getGroups() async {
    final res = await _client.get('/groups');
    return res['data'];
  }

  Future<void> createGroup(String name) async {
    await _client.post('/groups', data: {'name': name});
  }

  Future<void> deleteGroup(String id) async {
    await _client.delete('/groups/$id');
  }

  /// 发送邀请（对方在「待处理邀请」同意后加入家庭组）
  Future<void> addMember(String groupId, String phone) async {
    await _client.post('/groups/$groupId/members', data: {'phone': phone});
  }

  Future<List<dynamic>> getFamilyInvitations() async {
    final res = await _client.get('/groups/invitations');
    final d = res['data'];
    if (d is List) return d;
    return [];
  }

  Future<void> respondFamilyInvitation(String invitationId, bool accept) async {
    await _client.put('/groups/invitations/$invitationId', data: {'accept': accept});
  }

  Future<void> removeMember(String groupId, String memberId) async {
    await _client.delete('/groups/$groupId/members/$memberId');
  }

  Future<List<dynamic>> getSharing() async {
    final res = await _client.get('/sharing');
    return res['data'];
  }

  Future<void> requestSharing(String phone) async {
    final t = phone.trim();
    if (t.isEmpty) return;
    await _client.post('/sharing', data: {'phone': t});
  }

  Future<void> respondSharing(String id, bool accept) async {
    await _client.put('/sharing/$id/respond', data: {'accept': accept});
  }

  Future<void> updateSharing(String id, {bool? isPaused}) async {
    await _client.put('/sharing/$id', data: {if (isPaused != null) 'is_paused': isPaused});
  }

  Future<void> deleteSharing(String id) async {
    await _client.delete('/sharing/$id');
  }

  /// 家庭页：向同家庭成员开启/关闭位置共享（当前用户为 owner，对方为 viewer）
  Future<void> setSharingPeer(String viewerId, bool enabled) async {
    await _client.put('/sharing/peer/$viewerId', data: {'enabled': enabled});
  }
}
