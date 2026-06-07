import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        if (envUrl.contains('localhost')) {
          return envUrl.replaceAll('localhost', '10.0.2.2');
        }
        if (envUrl.contains('127.0.0.1')) {
          return envUrl.replaceAll('127.0.0.1', '10.0.2.2');
        }
      }
      return envUrl;
    }

    // Provide a fallback for production (Vercel) if not passed via build args
    if (kIsWeb) {
      // Default to the provided production backend
      return 'https://stock-management-and-tax-warning.vercel.app/api/'; 
    }
    
    // Default fallback for mobile
    return 'http://10.0.2.2:3000/api/';
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
              final lowerMsg = errorMessage.toLowerCase();
              if (lowerMsg.contains('invalid credentials')) {
                errorMessage = 'Sai tên đăng nhập hoặc mật khẩu';
              } else if (lowerMsg.contains('username already exists') ||
                  lowerMsg.contains('phone already exists')) {
                errorMessage = 'Tên đăng nhập / Số điện thoại này đã tồn tại';
              } else if (lowerMsg.contains('email already exists')) {
                errorMessage = 'Email này đã tồn tại trong hệ thống';
              } else if (lowerMsg.contains('jwt expired')) {
                errorMessage = 'Phiên làm việc hết hạn';
              } else if (lowerMsg.contains('unauthorized')) {
                errorMessage = 'Không có quyền truy cập';
              } else if (lowerMsg.contains('user not found') ||
                  lowerMsg.contains('invalid user')) {
                errorMessage = 'Không tìm thấy tài khoản';
              } else if (lowerMsg.contains('account is inactive')) {
                errorMessage = 'Tài khoản đã bị khóa hoặc chưa kích hoạt';
              } else if (lowerMsg.contains('not found')) {
                if (lowerMsg.contains('customer')) {
                  errorMessage = 'Không tìm thấy thông tin khách hàng';
                } else if (lowerMsg.contains('invoice')) {
                  errorMessage = 'Không tìm thấy hóa đơn';
                } else if (lowerMsg.contains('purchaseorder')) {
                  errorMessage = 'Không tìm thấy đơn nhập hàng';
                } else if (lowerMsg.contains('warehouse')) {
                  errorMessage = 'Không tìm thấy kho hàng';
                } else {
                  errorMessage = 'Không tìm thấy dữ liệu';
                }
              } else if (lowerMsg.contains('internal server error')) {
                errorMessage = 'Lỗi máy chủ nội bộ';
              } else if (lowerMsg.contains('bad request')) {
                errorMessage = 'Yêu cầu không hợp lệ';
              } else if (lowerMsg.contains('already exists')) {
                if (lowerMsg.contains('sku')) {
                  errorMessage = 'Mã SKU đã tồn tại trong hệ thống';
                } else if (lowerMsg.contains('barcode')) {
                  errorMessage = 'Mã vạch đã tồn tại trong hệ thống';
                } else {
                  errorMessage = 'Dữ liệu đã tồn tại';
                }
              } else if (lowerMsg.contains('validation') ||
                  lowerMsg.contains('missing')) {
                errorMessage = 'Dữ liệu cung cấp không hợp lệ hoặc bị thiếu';
              } else if (lowerMsg.contains('double-entry validation failed')) {
                errorMessage =
                    'Lỗi hạch toán kép: Tổng phát sinh Nợ và Có không cân bằng';
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
  void setShopId(String? shopId) {
    _shopId = shopId;
    SharedPreferences.getInstance().then((prefs) {
      if (shopId != null) {
        prefs.setString('shop_id', shopId);
      } else {
        prefs.remove('shop_id');
      }
    });
  }

  String? get shopId => _shopId;
  Dio get dio => _dio;

  /// All NestJS endpoints return { success, data, message }
  /// This extracts the `data` field.
  dynamic _extract(Response res) {
    final body = res.data;
    if (body is Map) {
      if (body.containsKey('success') && body['success'] == false) {
        throw ApiException(
          body['message'] ?? 'Lỗi không xác định',
          res.statusCode,
        );
      }
      if (body.containsKey('data')) {
        return body['data'];
      }
    }
    return body;
  }

  String _cleanPath(String path) => path.startsWith('/') ? path.substring(1) : path;

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    try {
      final res = await _dio.get(_cleanPath(path), queryParameters: params);
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(e.message ?? 'Lỗi không xác định');
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final res = await _dio.post(_cleanPath(path), data: data);
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(e.message ?? 'Lỗi không xác định');
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final res = await _dio.put(_cleanPath(path), data: data);
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(e.message ?? 'Lỗi không xác định');
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final res = await _dio.delete(_cleanPath(path));
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(e.message ?? 'Lỗi không xác định');
    }
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _refreshToken = prefs.getString('refresh_token');
    _shopId = prefs.getString('shop_id');
  }

  Future<void> saveToken(String token, [String? refreshToken]) async {
    _token = token;
    _refreshToken = refreshToken ?? _refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    if (refreshToken != null) {
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
