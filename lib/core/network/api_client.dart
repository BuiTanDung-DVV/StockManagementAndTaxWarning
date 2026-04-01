import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced API client with auth token management
class ApiClient {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    const defaultUrl = 'https://stockmanagementandtaxwarning.onrender.com/api';

    if (const bool.fromEnvironment('dart.library.html')) return defaultUrl;
    // Use an environment variable or compile-time constant for web, else check platform
    try {
      if (Platform.isAndroid) return defaultUrl;
    } catch (e) {
      // Platform.isAndroid throws on web
    }
    return defaultUrl;
  }
  
  late final Dio _dio;
  String? _token;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opts, handler) {
        if (_token != null) {
          opts.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(opts);
      },
      onError: (e, handler) {
        // 401 → clear token
        if (e.response?.statusCode == 401) {
          _token = null;
        }
        handler.next(e);
      },
    ));
  }

  void setToken(String? token) => _token = token;
  String? get token => _token;
  Dio get dio => _dio;

  /// All NestJS endpoints return { success, data, message }
  /// This extracts the `data` field.
  dynamic _extract(Response res) {
    final body = res.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    final res = await _dio.get(path, queryParameters: params);
    return _extract(res);
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    final res = await _dio.post(path, data: data);
    return _extract(res);
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    final res = await _dio.put(path, data: data);
    return _extract(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await _dio.delete(path);
    return _extract(res);
  }

  /// Load token from SharedPreferences on startup
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
}

/// Global provider for ApiClient — singleton
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
