import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_logger.dart';

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
    final buf = StringBuffer()
      ..write('→ ${options.method} ${options.uri}');
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

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: 'http://www.synerunify.com:40808/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    // 先注入 token，再记录日志，保证能看到「已带鉴权」
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
        }
        handler.next(error);
      },
    ));
    if (!kReleaseMode) {
      dio.interceptors.add(_ApiLogInterceptor());
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? params}) async {
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

  Future<void> delete(String path) async {
    await dio.delete(path);
  }
}
