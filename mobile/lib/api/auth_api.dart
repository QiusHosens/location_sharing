import 'package:dio/dio.dart';
import 'client.dart';

class AuthApi {
  final Dio _client = ApiClient().dio;

  Future<Map<String, dynamic>> register(String phone, String password) async {
    final res = await _client.post('/auth/register', data: {'phone': phone, 'password': password});
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final res = await _client.post('/auth/login', data: {'phone': phone, 'password': password});
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }
}
