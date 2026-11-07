import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage.dart';
import 'configure_dio.dart';
import 'data_change_bridge.dart';
import 'data_change_transport.dart';
import '../offline/offline_read_cache.dart';
import '../providers/data_freshness_provider.dart';

/// Custom App API Exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;
  ApiException(this.message, [this.statusCode, this.details]);
  @override
  String toString() => message;
}

/// Enhanced API client with auth token management
class ApiClient {
  OfflineReadCache? readCache;
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (kIsWeb) {
      final pageUri = Uri.base;
      final isLocalPage =
          pageUri.host == 'localhost' ||
          pageUri.host == '127.0.0.1' ||
          pageUri.host == '0.0.0.0';
      if (!isLocalPage && pageUri.hasScheme && pageUri.host.isNotEmpty) {
        return '${pageUri.origin}/api/';
      }
    }
    if (envUrl.isNotEmpty) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        if (envUrl.contains('localhost')) {
          return envUrl.replaceAll('localhost', '10.0.2.2');
        }
        if (envUrl.contains('127.0.0.1')) {
          return envUrl.replaceAll('127.0.0.1', '10.0.2.2');
        }
      }
      return envUrl.endsWith('/') ? envUrl : '$envUrl/';
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
  Future<bool>? _refreshFuture;
  bool _sessionRestoreCompleted = false;
  int _credentialVersion = 0;
  int _actorVersion = 0;
  bool _refreshUnavailable = false;
  bool get refreshUnavailable => _refreshUnavailable;
  bool localOnlyMode = false;
  final Dio? _sessionDio;
  final AuthTokenStorage _tokenStorage;
  void Function()? onSessionExpired;
  void Function(Set<DataArea>)? onDataChanged;

  ApiClient({AuthTokenStorage? tokenStorage, Dio? sessionDio})
    : _tokenStorage = tokenStorage ?? SecureAuthTokenStorage(),
      _sessionDio = sessionDio {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'X-Client-Platform': kIsWeb ? 'web' : 'native',
          if (kIsWeb) 'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );
    configureDioForPlatform(_dio);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) {
          opts.extra.putIfAbsent(
            'dataFreshnessActorVersion',
            () => _actorVersion,
          );
          if (opts.extra['pinMutationScope'] == true &&
              (opts.extra['dataFreshnessActorVersion'] != _actorVersion ||
                  opts.extra['dataFreshnessShop'] != _shopId)) {
            return handler.reject(
              DioException(
                requestOptions: opts,
                type: DioExceptionType.cancel,
                error: ApiException(
                  'Đã đổi tài khoản hoặc cửa hàng. Thao tác chưa được gửi.',
                  409,
                ),
              ),
            );
          }
          final verifyingIdentity =
              opts.method == 'GET' &&
              opts.extra['verifyLocalSession'] == true &&
              const ['profile', 'my-shops'].contains(_cleanPath(opts.path));
          if (localOnlyMode &&
              !_isPublicAuthRequest(opts) &&
              !verifyingIdentity) {
            return handler.reject(
              DioException(
                requestOptions: opts,
                type: DioExceptionType.connectionError,
                error: ApiException(
                  'Đang dùng dữ liệu trên thiết bị. Kết nối lại để gửi dữ liệu.',
                ),
              ),
            );
          }
          final scopeGuard = opts.extra['scopeGuard'];
          if (scopeGuard is bool Function() && !scopeGuard()) {
            return handler.reject(
              DioException(
                requestOptions: opts,
                type: DioExceptionType.cancel,
                error: ApiException(
                  'Đã đổi tài khoản hoặc cửa hàng. Bản ghi chưa được gửi.',
                  409,
                ),
              ),
            );
          }
          if (_token != null) {
            opts.headers['Authorization'] = 'Bearer $_token';
          }
          if (opts.extra['offlineShopId'] is String) {
            opts.headers['x-shop-id'] = opts.extra['offlineShopId'];
          } else if (_shopId != null) {
            opts.headers['x-shop-id'] = _shopId;
          }
          handler.next(opts);
        },
        onResponse: (response, handler) {
          final request = response.requestOptions;
          final body = response.data;
          final requestShop = request.headers['x-shop-id']?.toString();
          if ((response.statusCode ?? 0) >= 200 &&
              (response.statusCode ?? 0) < 300 &&
              !(body is Map && body['success'] == false) &&
              request.extra['dataFreshnessActorVersion'] == _actorVersion &&
              requestShop == _shopId) {
            final areas = mutationDataAreas(request.method, request.path);
            if (areas.isNotEmpty) onDataChanged?.call(areas);
          }
          handler.next(response);
        },
        onError: (e, handler) async {
          if (e.type == DioExceptionType.cancel && e.error is ApiException) {
            return handler.next(e);
          }
          // 401 → Try to refresh token
          if (e.response?.statusCode == 401 &&
              !_isPublicAuthRequest(e.requestOptions) &&
              e.requestOptions.extra['authRetried'] != true) {
            final refreshed = await _refreshOnce();
            if (refreshed && _token != null) {
              final opts = e.requestOptions;
              opts.extra['authRetried'] = true;
              opts.headers['Authorization'] = 'Bearer $_token';
              try {
                final retryRes = await _dio.fetch(opts);
                return handler.resolve(retryRes);
              } on DioException catch (retryError) {
                // Resolve the original interceptor even when the retry fails.
                return handler.reject(retryError);
              }
            }
            if (_refreshUnavailable) {
              return handler.reject(
                DioException(
                  requestOptions: e.requestOptions,
                  type: DioExceptionType.connectionError,
                  error: ApiException(
                    'Chưa kết nối được máy chủ để xác thực lại. Nội dung đã lưu được giữ nguyên.',
                  ),
                ),
              );
            }
            await clearToken();
            onSessionExpired?.call();
          }
          if (e.response?.statusCode == 401 &&
              !_isPublicAuthRequest(e.requestOptions) &&
              e.requestOptions.extra['authRetried'] == true) {
            await clearToken();
            onSessionExpired?.call();
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
                errorMessage = 'Sai Gmail hoặc mật khẩu';
              } else if (lowerMsg.contains('username already exists') ||
                  lowerMsg.contains('phone already exists')) {
                errorMessage = 'Gmail hoặc tên đăng nhập này đã tồn tại';
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
              } else if (lowerMsg.contains('customer not found')) {
                errorMessage = 'Không tìm thấy thông tin khách hàng';
              } else if (lowerMsg.contains('invoice not found')) {
                errorMessage = 'Không tìm thấy hóa đơn';
              } else if (lowerMsg.contains('purchaseorder not found')) {
                errorMessage = 'Không tìm thấy đơn nhập hàng';
              } else if (lowerMsg.contains('warehouse not found')) {
                errorMessage = 'Không tìm thấy kho hàng';
              } else if (lowerMsg.contains('contain at least 3 character')) {
                errorMessage =
                    'Gmail hoặc tên đăng nhập phải từ 3 ký tự trở lên';
              } else if (lowerMsg.contains('contain at least 2 character')) {
                errorMessage = 'Họ và tên phải có ít nhất 2 ký tự';
              } else if (lowerMsg.contains('contain at least')) {
                errorMessage =
                    'Thông tin nhập vào quá ngắn, vui lòng kiểm tra lại';
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

  bool _isPublicAuthRequest(RequestOptions options) {
    final path = options.path.toLowerCase();
    return path.contains('auth/login') ||
        path.contains('auth/register') ||
        path.contains('auth/google') ||
        path.contains('auth/refresh-token') ||
        path.contains('auth/forgot-password') ||
        path.contains('auth/reset-password') ||
        path.contains('auth/send-otp');
  }

  Dio _createSessionDio() {
    if (_sessionDio != null) return _sessionDio;
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'X-Client-Platform': kIsWeb ? 'web' : 'native',
          if (kIsWeb) 'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );
    configureDioForPlatform(dio);
    return dio;
  }

  Future<bool> _performRefresh() async {
    final version = _credentialVersion;
    final actorVersion = _actorVersion;
    _refreshUnavailable = false;
    if (!kIsWeb && (_refreshToken == null || _refreshToken!.isEmpty)) {
      return false;
    }
    try {
      final response = await _createSessionDio().post(
        'auth/refresh-token',
        data: kIsWeb ? <String, dynamic>{} : {'refresh_token': _refreshToken},
      );
      final body = response.data;
      if (body is! Map || body['success'] != true || body['data'] is! Map) {
        _refreshUnavailable = true;
        return false;
      }
      final data = Map<String, dynamic>.from(body['data'] as Map);
      final access = data['access_token']?.toString();
      if (access == null || access.isEmpty) {
        _refreshUnavailable = true;
        return false;
      }
      if (version != _credentialVersion) {
        _refreshUnavailable = true;
        return false;
      }
      await _storeTokens(access, data['refresh_token']?.toString());
      if (actorVersion != _actorVersion) {
        _refreshUnavailable = true;
        return false;
      }
      return true;
    } on DioException catch (error) {
      _refreshUnavailable =
          error.response == null ||
          const [
            408,
            429,
            500,
            502,
            503,
            504,
          ].contains(error.response?.statusCode);
      return false;
    } catch (_) {
      _refreshUnavailable = true;
      return false;
    }
  }

  Future<bool> _refreshOnce() {
    final active = _refreshFuture;
    if (active != null) return active;
    final future = _performRefresh();
    _refreshFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_refreshFuture, future)) _refreshFuture = null;
      }),
    );
    return future;
  }

  Future<bool> refreshSession() => _refreshOnce();

  // Only identity reads bypass the local-mode gate while reconnecting.
  // Other reads/writes stay blocked until AuthNotifier verifies actor and shop.
  Future<dynamic> getSessionIdentity(String path) async {
    if (!const ['profile', 'my-shops'].contains(_cleanPath(path))) {
      throw ArgumentError('Chỉ được kiểm tra danh tính và quyền cửa hàng.');
    }
    try {
      return _extract(
        await _dio.get(
          _cleanPath(path),
          options: Options(extra: {'verifyLocalSession': true}),
        ),
      );
    } on DioException catch (error) {
      if (error.error is ApiException) throw error.error!;
      throw ApiException(
        'Chưa xác thực lại được phiên làm việc.',
        error.response?.statusCode,
      );
    }
  }

  void setToken(String? token) {
    _credentialVersion++;
    _actorVersion++;
    _token = token;
  }

  String? get token => _token;
  int get sessionVersion => _actorVersion;
  bool get sessionRestoreCompleted => _sessionRestoreCompleted;
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

  String _cleanPath(String path) =>
      path.startsWith('/') ? path.substring(1) : path;

  Map<String, dynamic> _mutationScope() => {
    'pinMutationScope': true,
    'dataFreshnessActorVersion': _actorVersion,
    'dataFreshnessShop': _shopId,
  };

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    try {
      final res = await _dio.get(_cleanPath(path), queryParameters: params);
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(
        e.message ?? 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
        e.response?.statusCode,
      );
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final res = await _dio.post(
        _cleanPath(path),
        data: data,
        options: Options(extra: _mutationScope()),
      );
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(e.message ?? 'Lỗi không xác định');
    }
  }

  /// Preparation must reach the server, never reuse an older cached page and
  /// label it a freshly downloaded complete catalog.
  Future<dynamic> getOnlineInShop(
    String path,
    String shopId, {
    Map<String, dynamic>? params,
    required bool Function() isCurrentScope,
  }) async {
    if (!isCurrentScope() || _shopId != shopId) {
      throw ApiException('Phạm vi tải dữ liệu đã thay đổi.', 409);
    }
    try {
      final response = await _dio.get(
        _cleanPath(path),
        queryParameters: params,
        options: Options(
          extra: {'offlineShopId': shopId, 'scopeGuard': isCurrentScope},
        ),
      );
      if (!isCurrentScope() || _shopId != shopId) {
        throw ApiException('Phạm vi tải dữ liệu đã thay đổi.', 409);
      }
      return _extract(response);
    } on DioException catch (error) {
      if (const [403, 404].contains(error.response?.statusCode)) {
        final cache = readCache;
        final access = cache?.access(path, params);
        if (cache != null && access != null) {
          try {
            await cache.invalidate(access);
          } catch (_) {
            /* Keep the server denial. */
          }
        }
      }
      if (error.error is ApiException) throw error.error!;
      throw ApiException(
        'Chưa tải được dữ liệu mới từ máy chủ.',
        error.response?.statusCode,
      );
    }
  }

  Future<dynamic> postInShop(
    String path,
    String shopId,
    Map<String, dynamic> data, {
    required bool Function() isCurrentScope,
  }) async {
    if (!isCurrentScope() || _shopId != shopId) {
      throw ApiException('Cửa hàng đã thay đổi. Bản ghi chưa được gửi.', 409);
    }
    try {
      final response = await _dio.post(
        _cleanPath(path),
        data: data,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          extra: {
            ..._mutationScope(),
            'offlineShopId': shopId,
            'scopeGuard': isCurrentScope,
          },
        ),
      );
      return _extract(response);
    } on DioException catch (error) {
      final body = error.response?.data;
      if (error.response?.statusCode == 409 &&
          body is Map &&
          body['code'] == 'SYNC_REVIEW_REQUIRED' &&
          body['review'] is Map) {
        throw ApiException(
          body['message']?.toString() ?? 'Cần kiểm tra giao dịch tương tự.',
          409,
          Map<String, dynamic>.from(body['review'] as Map),
        );
      }
      if (error.error is ApiException) throw error.error!;
      throw ApiException(
        'Chưa kết nối được máy chủ. Bản ghi vẫn ở trên thiết bị.',
        error.response?.statusCode,
      );
    }
  }

  Future<dynamic> putInShop(
    String path,
    String shopId, {
    dynamic data,
    required bool Function() isCurrentScope,
  }) => _writeInShop('PUT', path, shopId, data, isCurrentScope);

  Future<dynamic> deleteInShop(
    String path,
    String shopId, {
    required bool Function() isCurrentScope,
  }) => _writeInShop('DELETE', path, shopId, null, isCurrentScope);

  Future<dynamic> _writeInShop(
    String method,
    String path,
    String shopId,
    dynamic data,
    bool Function() isCurrentScope,
  ) async {
    if (!isCurrentScope() || _shopId != shopId) {
      throw ApiException('Cửa hàng đã thay đổi. Thao tác chưa được gửi.', 409);
    }
    try {
      final response = await _dio.request(
        _cleanPath(path),
        data: data,
        options: Options(
          method: method,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          extra: {
            ..._mutationScope(),
            'offlineShopId': shopId,
            'scopeGuard': isCurrentScope,
          },
        ),
      );
      return _extract(response);
    } on DioException catch (error) {
      if (error.error is ApiException) throw error.error!;
      throw ApiException(
        'Chưa xác định được kết quả. Hãy tải lại đơn trước khi thao tác tiếp.',
        error.response?.statusCode,
      );
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final res = await _dio.put(
        _cleanPath(path),
        data: data,
        options: Options(extra: _mutationScope()),
      );
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(e.message ?? 'Lỗi không xác định');
    }
  }

  Future<dynamic> delete(String path, {dynamic data}) async {
    try {
      final res = await _dio.delete(
        _cleanPath(path),
        data: data,
        options: Options(extra: _mutationScope()),
      );
      return _extract(res);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(e.message ?? 'Lỗi không xác định');
    }
  }

  Future<Uint8List> postForBytes(String path, {dynamic data}) async {
    try {
      final res = await _dio.post<List<int>>(
        _cleanPath(path),
        data: data,
        options: Options(
          responseType: ResponseType.bytes,
          extra: _mutationScope(),
        ),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(
        'Không thể tải bản sao dữ liệu',
        e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> postGzip(
    String path,
    Uint8List bytes,
    String password,
  ) async {
    try {
      final res = await _dio.post(
        _cleanPath(path),
        data: bytes,
        options: Options(
          contentType: 'application/gzip',
          headers: {'x-backup-password': password},
          extra: _mutationScope(),
        ),
      );
      return Map<String, dynamic>.from(_extract(res) as Map);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(
        'Không thể kiểm tra bản sao dữ liệu',
        e.response?.statusCode,
      );
    }
  }

  /// Sends image bytes to the authenticated backend. Storage credentials and
  /// provider-specific signing never leave the server.
  Future<Map<String, dynamic>> postImage(
    String path,
    Uint8List bytes,
    String fileName,
    String contentType,
  ) async {
    try {
      final response = await _dio.post(
        _cleanPath(path),
        data: bytes,
        options: Options(
          contentType: contentType,
          headers: {'x-file-name': fileName},
          extra: _mutationScope(),
        ),
      );
      return Map<String, dynamic>.from(_extract(response) as Map);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(
        'Không thể tải ảnh lên máy chủ',
        e.response?.statusCode,
      );
    }
  }

  Future<void> loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _shopId = prefs.getString('shop_id');
      if (prefs.getBool('session_restore_disabled') == true) return;
      if (kIsWeb) {
        // main() restores the HttpOnly-cookie session before ProviderScope.
        // Avoid rotating the same refresh token again in AuthNotifier.init().
        if (_token == null || _token!.isEmpty) {
          await _refreshOnce();
        }
        return;
      }

      _token = await _tokenStorage.read('auth_token');
      _refreshToken = await _tokenStorage.read('refresh_token');

      // One-time migration from legacy SharedPreferences storage.
      final legacyAccess = prefs.getString('auth_token');
      final legacyRefresh = prefs.getString('refresh_token');
      if (_token == null && legacyAccess != null) {
        await _tokenStorage.write('auth_token', legacyAccess);
        _token = legacyAccess;
      }
      if (_refreshToken == null && legacyRefresh != null) {
        await _tokenStorage.write('refresh_token', legacyRefresh);
        _refreshToken = legacyRefresh;
      }
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
    } finally {
      _sessionRestoreCompleted = true;
    }
  }

  Future<void> saveToken(String token, [String? refreshToken]) async {
    _actorVersion++;
    await _storeTokens(token, refreshToken);
  }

  Future<void> _storeTokens(String token, String? refreshToken) async {
    _credentialVersion++;
    _token = token;
    _refreshToken = refreshToken ?? _refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_restore_disabled');
    if (kIsWeb) return;
    await _tokenStorage.write('auth_token', token);
    if (refreshToken != null) {
      await _tokenStorage.write('refresh_token', refreshToken);
    }
  }

  Future<void> clearToken() async {
    _credentialVersion++;
    _actorVersion++;
    _token = null;
    _refreshToken = null;
    if (!kIsWeb) {
      await _tokenStorage.delete('auth_token');
      await _tokenStorage.delete('refresh_token');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  Future<void> revokeSession() async {
    final refresh = _refreshToken;
    // Disable reopening before waiting on an unreachable logout endpoint.
    // A refresh already in flight must not restore credentials after this.
    await clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_restore_disabled', true);
    try {
      await _createSessionDio().post(
        'auth/logout',
        data: kIsWeb ? <String, dynamic>{} : {'refresh_token': refresh},
      );
    } finally {
      await clearToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('session_restore_disabled', true);
    }
  }

  /// The server has already revoked every session after an email change.
  Future<void> discardRevokedSession() async {
    await clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_restore_disabled', true);
  }
}

/// Global provider for ApiClient — singleton
final apiClientProvider = Provider<ApiClient>((ref) {
  final api = ApiClient();
  late final DataChangeBridge bridge;
  final transport = openDataChangeTransport((message) {
    if (ref.mounted) bridge.receive(message);
  });
  bridge = DataChangeBridge(
    currentShop: () => api.shopId,
    isAuthenticated: () => api.token != null && !api.localOnlyMode,
    invalidate: (areas) {
      if (ref.mounted) ref.read(dataFreshnessProvider.notifier).changed(areas);
    },
    send: transport.publish,
  );
  api.onDataChanged = (areas) {
    if (ref.mounted) {
      ref.read(dataFreshnessProvider.notifier).changed(areas);
      bridge.committed(areas);
    }
  };
  ref.onDispose(() {
    api.onDataChanged = null;
    transport.dispose();
  });
  return api;
});
