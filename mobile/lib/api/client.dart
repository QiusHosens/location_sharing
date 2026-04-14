import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_logger.dart';

/// 刷新成功后写入 SharedPreferences 并更新 [AuthNotifier] 状态。
typedef OnTokensRefreshed = Future<void> Function(String access, String refresh);

/// 统一记录 HTTP 请求/响应（非 release）。Authorization 仅标记是否携带，不打印 token。
class _ApiLogInterceptor extends Interceptor {
  static const int _maxBodyLen = 4000;

  String _truncate(Object? data) {
    if (data == null) return '';
    final s = data.toString();
    if (s.length <= _maxBodyLen) return s;
    return '${s.substring(0, _maxBodyLen)}…(${s.length} chars)';
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final hasAuth = options.headers.containsKey('Authorization');
    final buf = StringBuffer()..write('→ ${options.method} ${options.uri}');
    if (options.queryParameters.isNotEmpty) {
      buf.write('\n  query: ${options.queryParameters}');
    }
    if (options.data != null) {
      buf.write('\n  body: ${_truncate(options.data)}');
    }
    buf.write('\n  auth: ${hasAuth ? 'Bearer ***' : 'none'}');
    appLogger.d('[HTTP] $buf');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    appLogger.d(
      '[HTTP] ← ${response.statusCode} ${response.requestOptions.uri}\n'
      '  body: ${_truncate(response.data)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final r = err.response;
    appLogger.e(
      '[HTTP] ✗ ${err.requestOptions.method} ${err.requestOptions.uri}\n'
      '  type: ${err.type} message: ${err.message}\n'
      '  status: ${r?.statusCode} body: ${_truncate(r?.data)}',
    );
    handler.next(err);
  }
}

typedef UnauthorizedHandler = Future<void> Function();

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;

  static UnauthorizedHandler? _onUnauthorized;
  static OnTokensRefreshed? _onTokensRefreshed;

  static Future<void>? _refreshFuture;

  /// 在带 [ProviderScope] 的根组件中注册；dispose 时传 `null` 解除。
  static void setUnauthorizedHandler(UnauthorizedHandler? handler) {
    _onUnauthorized = handler;
  }

  static void setOnTokensRefreshed(OnTokensRefreshed? handler) {
    _onTokensRefreshed = handler;
  }

  late final Dio dio;

  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: 'http://192.168.0.39:8080/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        final path = options.uri.path;
        final isLocationUpload =
            options.method.toUpperCase() == 'POST' && path.contains('/location/upload');
        if (token != null && !isLocationUpload) {
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          options.headers.remove('Authorization');
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode != 401) {
          handler.next(error);
          return;
        }
        final p = error.requestOptions.uri.path;
        if (p.contains('/auth/login') || p.contains('/auth/register')) {
          handler.next(error);
          return;
        }
        if (p.contains('/auth/refresh')) {
          try {
            await _onUnauthorized?.call();
          } catch (_) {}
          handler.next(error);
          return;
        }
        if (p.contains('/location/upload')) {
          handler.next(error);
          return;
        }
        if (error.requestOptions.extra['retry401'] == true) {
          try {
            await _onUnauthorized?.call();
          } catch (_) {}
          handler.next(error);
          return;
        }

        try {
          await _refreshTokens();
          final opts = error.requestOptions;
          opts.extra['retry401'] = true;
          final prefs = await SharedPreferences.getInstance();
          final t = prefs.getString('token');
          if (t != null) {
            opts.headers['Authorization'] = 'Bearer $t';
          }
          final response = await dio.fetch(opts);
          handler.resolve(response);
        } catch (_) {
          try {
            await _onUnauthorized?.call();
          } catch (_) {}
          handler.next(error);
        }
      },
    ));
    if (!kReleaseMode) {
      dio.interceptors.add(_ApiLogInterceptor());
    }
  }

  static Future<void> _refreshTokens() {
    if (_refreshFuture != null) return _refreshFuture!;
    _refreshFuture = _doRefresh().whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  static Future<void> _doRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final rt = prefs.getString('refresh_token');
    if (rt == null || rt.isEmpty) {
      throw StateError('no refresh_token');
    }

    final plain = Dio(BaseOptions(
      baseUrl: ApiClient().dio.options.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    final res = await plain.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': rt},
    );
    final data = res.data?['data'] as Map<String, dynamic>?;
    if (data == null) throw StateError('bad refresh response');

    final access = data['access_token'] as String?;
    final newRt = data['refresh_token'] as String?;
    if (access == null || newRt == null) {
      throw StateError('missing tokens in refresh response');
    }

    await prefs.setString('token', access);
    await prefs.setString('refresh_token', newRt);
    await _onTokensRefreshed?.call(access, newRt);
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? params}) async {
    final res = await dio.get(path, queryParameters: params);
    return res.data;
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data}) async {
    final res = await dio.post(path, data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> put(String path, {dynamic data}) async {
    final res = await dio.put(path, data: data);
    return res.data;
  }

  /// 去掉 BaseOptions 里的 JSON Content-Type，由 Dio 为 [FormData] 自动带 multipart boundary。
  Future<Map<String, dynamic>> postMultipart(String path, FormData data) async {
    final headers = Map<String, dynamic>.from(dio.options.headers);
    headers.remove(Headers.contentTypeHeader);
    headers.remove('content-type');
    final res = await dio.post<Map<String, dynamic>>(
      path,
      data: data,
      options: Options(headers: headers),
    );
    return res.data as Map<String, dynamic>;
  }

  /// 将接口返回的相对路径（如 `avatars/{user_id}`）拼成可访问的完整 URL。
  /// [BaseOptions.baseUrl] 无尾部 `/` 时，[Uri.resolve] 会错误丢掉最后一级路径，故先规范化。
  String? resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = dio.options.baseUrl;
    final normalized = base.endsWith('/') ? base : '$base/';
    return Uri.parse(normalized).resolve(path).toString();
  }

  Future<void> delete(String path) async {
    await dio.delete(path);
  }
}
