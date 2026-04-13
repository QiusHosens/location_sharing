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

  Future<void> addMember(String groupId, String phone) async {
    await _client.post('/groups/$groupId/members', data: {'phone': phone});
  }

  Future<void> removeMember(String groupId, String memberId) async {
    await _client.delete('/groups/$groupId/members/$memberId');
  }

  Future<List<dynamic>> getSharing() async {
    final res = await _client.get('/sharing');
    return res['data'];
  }

  Future<void> requestSharing(String targetUserId) async {
    await _client.post('/sharing', data: {'target_user_id': targetUserId});
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
}
