import 'client.dart';

class AuthApi {
  final _client = ApiClient();

  Future<void> sendCode(String phone) async {
    await _client.post('/auth/send-code', data: {'phone': phone});
  }

  Future<Map<String, dynamic>> verifyCode(String phone, String code) async {
    final res = await _client.post('/auth/verify-code', data: {'phone': phone, 'code': code});
    return res['data'];
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final res = await _client.post('/auth/refresh', data: {'refresh_token': refreshToken});
    return res['data'];
  }
}
