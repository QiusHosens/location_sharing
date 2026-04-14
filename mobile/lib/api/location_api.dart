import 'client.dart';

class LocationApi {
  final _client = ApiClient();

  Future<void> uploadLocation({
    required double longitude, required double latitude,
    double? altitude, double? speed, double? bearing, double? accuracy, String? source,
  }) async {
    await _client.post('/location/upload', data: {
      'longitude': longitude, 'latitude': latitude,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      if (bearing != null) 'bearing': bearing,
      if (accuracy != null) 'accuracy': accuracy,
      if (source != null) 'source': source,
    });
  }

  Future<Map<String, dynamic>?> getLatest() async {
    final res = await _client.get('/location/latest');
    return res['data'];
  }

  Future<Map<String, dynamic>> getSharedLocation(String userId) async {
    final res = await _client.get('/location/shared/$userId');
    return res['data'];
  }

  Future<List<dynamic>> getFamilyLocations(String groupId) async {
    final res = await _client.get('/location/family/$groupId');
    return res['data'];
  }

  Future<Map<String, dynamic>> getTrajectory(String userId, String startTime, String endTime) async {
    final res = await _client.get('/trajectory', params: {
      'user_id': userId, 'start_time': startTime, 'end_time': endTime,
    });
    return res['data'];
  }

  /// [date] 格式 YYYY-MM-DD（与后端 UTC 日历日对齐）
  Future<Map<String, dynamic>> getTrajectoryDaySummary(String date) async {
    final res = await _client.get('/trajectory/day-summary', params: {'date': date});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getNotifications({int page = 1, int pageSize = 20}) async {
    final res = await _client.get('/notifications', params: {'page': page, 'page_size': pageSize});
    return res['data'];
  }

  Future<void> markRead(String id) async {
    await _client.put('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _client.put('/notifications/read-all');
  }
}
