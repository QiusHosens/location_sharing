import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/auth_api.dart';

class AuthState {
  final String? token;
  final String? userId;
  final String? phone;
  final bool isLoading;
  const AuthState({this.token, this.userId, this.phone, this.isLoading = false});
  bool get isAuthenticated => token != null;
  AuthState copyWith({String? token, String? userId, String? phone, bool? isLoading}) =>
      AuthState(token: token ?? this.token, userId: userId ?? this.userId,
        phone: phone ?? this.phone, isLoading: isLoading ?? this.isLoading);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApi _api = AuthApi();
  AuthNotifier() : super(const AuthState()) { _loadFromPrefs(); }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = AuthState(
      token: prefs.getString('token'),
      userId: prefs.getString('user_id'),
      phone: prefs.getString('phone'),
    );
  }

  Future<void> sendCode(String phone) async {
    await _api.sendCode(phone);
  }

  Future<bool> verifyCode(String phone, String code) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.verifyCode(phone, code);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', res['access_token']);
      await prefs.setString('refresh_token', res['refresh_token']);
      await prefs.setString('user_id', res['user_id']);
      await prefs.setString('phone', phone);
      state = AuthState(token: res['access_token'], userId: res['user_id'], phone: phone);
      return true;
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
