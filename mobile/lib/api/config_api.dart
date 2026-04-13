import 'package:dio/dio.dart';
import 'client.dart';

class MapConfig {
  final String webKey;
  final String webSecuritySecret;
  final String androidKey;
  final String iosKey;

  MapConfig({
    required this.webKey,
    required this.webSecuritySecret,
    required this.androidKey,
    required this.iosKey,
  });

  factory MapConfig.fromJson(Map<String, dynamic> j) {
    return MapConfig(
      webKey: j['web_key'] as String? ?? '',
      webSecuritySecret: j['web_security_secret'] as String? ?? '',
      androidKey: j['android_key'] as String? ?? '',
      iosKey: j['ios_key'] as String? ?? '',
    );
  }
}

class ConfigApi {
  final Dio _client = ApiClient().dio;

  Future<MapConfig> getMapConfig() async {
    final res = await _client.get('/config/map');
    final data = res.data['data'] as Map<String, dynamic>;
    return MapConfig.fromJson(data);
  }
}
