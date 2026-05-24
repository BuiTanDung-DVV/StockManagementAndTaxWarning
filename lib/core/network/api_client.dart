import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Custom App API Exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// Enhanced API client with auth token management
class ApiClient {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    const defaultUrl =
        'https://stock-management-and-tax-warning.vercel.app/api';

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
  String? _refreshToken;
  String? _shopId;
  bool _isRefreshing = false;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) {
          if (_token != null) {
            opts.headers['Authorization'] = 'Bearer $_token';
          }
          if (_shopId != null) {
            opts.headers['x-shop-id'] = _shopId;
          }
          handler.next(opts);
        },
        onError: (e, handler) async {
          // 401 → Try to refresh token
          if (e.response?.statusCode == 401) {
            if (_refreshToken != null && !_isRefreshing) {
              _isRefreshing = true;
              try {
                final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
                final res = await refreshDio.post(
                  '/auth/refresh-token',
                  data: {'refresh_token': _refreshToken},
                );

                if (res.data['success'] == true && res.data['data'] != null) {
                  final newAccess = res.data['data']['access_token'];
                  final newRefresh = res.data['data']['refresh_token'];
                  await saveToken(newAccess, newRefresh);

                  // Retry requested failed API
                  final opts = e.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $newAccess';
                  final retryRes = await _dio.fetch(opts);
                  _isRefreshing = false;
                  return handler.resolve(retryRes);
                }
              } catch (_) {
                // Ignore and let it fall through
              }
              _isRefreshing = false;
            }
            await clearToken();
          }

          // Global Error Formatting
          String errorMessage = 'Có lỗi kết nối, vui lòng thử lại';
          if (e.response?.data != null) {
            final data = e.response!.data;
            if (data is Map && data['message'] != null) {
              errorMessage = data['message'].toString();
              // Common translations
              if (errorMessage.contains('Invalid credentials')) {
                errorMessage = 'Sai tên đăng nhập hoặc mật khẩu gốc';
              } else if (errorMessage.contains('Username already exists')) {
                errorMessage = 'Tên đăng nhập / Số điện thoại này đã tồn tại';
              } else if (errorMessage.contains('jwt expired')) {
                errorMessage = 'Phiên làm việc hết hạn';
              } else if (errorMessage.contains('Unauthorized')) {
                errorMessage = 'Không có quyền truy cập';
              }
            }
          } else if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            errorMessage = 'Máy chủ phản hồi quá lâu, vui lòng kiểm tra mạng';
          }

          final customError = DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: ApiException(errorMessage, e.response?.statusCode),
          );
          handler.next(customError);
        },
      ),
    );
  }

  void setToken(String? token) => _token = token;
  String? get token => _token;
  void setShopId(String? shopId) => _shopId = shopId;
  String? get shopId => _shopId;
  Dio get dio => _dio;

  /// All NestJS endpoints return { success, data, message }
  /// This extracts the `data` field.
  dynamic _extract(Response res) {
    final body = res.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    try {
      final res = await _dio.get(path, queryParameters: params);
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(e.message ?? 'Lỗi không xác định');
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final res = await _dio.post(path, data: data);
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(e.message ?? 'Lỗi không xác định');
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final res = await _dio.put(path, data: data);
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(e.message ?? 'Lỗi không xác định');
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final res = await _dio.delete(path);
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(e.message ?? 'Lỗi không xác định');
    }
  }

  /// Load token from SharedPreferences on startup
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  Future<void> saveToken(String token, [String? refreshToken]) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await prefs.setString('refresh_token', refreshToken);
    }
  }

  Future<void> clearToken() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }
}

/// Global provider for ApiClient — singleton
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
