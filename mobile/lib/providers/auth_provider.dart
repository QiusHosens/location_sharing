import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/auth_api.dart';
import '../app_logger.dart';

/// 从 Dio 响应体或异常类型中提取对用户可见的说明。
String dioErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final err = data['error']?.toString();
    if (err != null && err.isNotEmpty) return err;
    final msg = data['message']?.toString();
    if (msg != null && msg.isNotEmpty) return msg;
  }
  if (data is String && data.isNotEmpty) return data;
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      '网络超时，请稍后重试',
    DioExceptionType.connectionError => '无法连接服务器，请检查网络与接口地址',
    DioExceptionType.badCertificate => '安全证书异常，无法建立连接',
    _ => e.message?.isNotEmpty == true ? e.message! : '请求失败，请稍后重试',
  };
}

class AuthState {
  final String? token;
  final String? userId;
  final String? phone;
  final bool isLoading;
  const AuthState(
      {this.token, this.userId, this.phone, this.isLoading = false});
  bool get isAuthenticated => token != null;
  AuthState copyWith(
          {String? token, String? userId, String? phone, bool? isLoading}) =>
      AuthState(
          token: token ?? this.token,
          userId: userId ?? this.userId,
          phone: phone ?? this.phone,
          isLoading: isLoading ?? this.isLoading);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApi _api = AuthApi();
  AuthNotifier() : super(const AuthState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = AuthState(
      token: prefs.getString('token'),
      userId: prefs.getString('user_id'),
      phone: prefs.getString('phone'),
    );
  }

  /// 成功返回 `null`，失败返回可读错误文案（账号密码等保留在输入框，由界面展示错误）。
  Future<String?> login(String phone, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.login(phone, password);
      final prefs = await SharedPreferences.getInstance();
      final uid = res['user_id']?.toString() ?? '';
      await prefs.setString('token', res['access_token'] as String);
      await prefs.setString('refresh_token', res['refresh_token'] as String);
      await prefs.setString('user_id', uid);
      await prefs.setString('phone', phone);
      state = AuthState(
          token: res['access_token'] as String, userId: uid, phone: phone);
      return null;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false);
      appLogger.e('[login] ${e.type} ${e.message} ${e.response?.data}');
      return dioErrorMessage(e);
    } catch (e, st) {
      state = state.copyWith(isLoading: false);
      appLogger.e('[login] $e', error: e, stackTrace: st);
      return '登录失败，请稍后重试';
    }
  }

  /// 成功返回 `null`，失败返回可读错误文案。
  Future<String?> register(String phone, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.register(phone, password);
      final prefs = await SharedPreferences.getInstance();
      final uid = res['user_id']?.toString() ?? '';
      await prefs.setString('token', res['access_token'] as String);
      await prefs.setString('refresh_token', res['refresh_token'] as String);
      await prefs.setString('user_id', uid);
      await prefs.setString('phone', phone);
      state = AuthState(
          token: res['access_token'] as String, userId: uid, phone: phone);
      return null;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false);
      appLogger.e('[register] ${e.type} ${e.message} ${e.response?.data}');
      return dioErrorMessage(e);
    } catch (e, st) {
      state = state.copyWith(isLoading: false);
      appLogger.e('[register] $e', error: e, stackTrace: st);
      return '注册失败，请稍后重试';
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AuthState();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
