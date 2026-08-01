import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/network/auth_token_storage.dart';

class MemoryAuthTokenStorage implements AuthTokenStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient Tests', () {
    late ApiClient apiClient;
    late MemoryAuthTokenStorage tokenStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tokenStorage = MemoryAuthTokenStorage();
      apiClient = ApiClient(tokenStorage: tokenStorage);
    });

    test('baseUrl should be valid for the current platform', () {
      final uri = Uri.parse(ApiClient.baseUrl);

      expect(uri.hasScheme, true);
      expect(uri.host, isNotEmpty);
      expect(uri.path.endsWith('/api/'), true);
      expect(
        uri.host,
        anyOf('stock-management-and-tax-warning.vercel.app', '10.0.2.2'),
        reason:
            'Web phải dùng backend Vercel, còn Android local dùng địa chỉ máy chủ giả lập.',
      );
    });

    test('Should persist and load auth token securely', () async {
      await apiClient.saveToken('test_fake_token_123');
      final restored = ApiClient(tokenStorage: tokenStorage);
      await restored.loadToken();

      expect(
        restored.token,
        'test_fake_token_123',
        reason: 'Token save/load process failed!',
      );
    });

    test('Should migrate tokens out of legacy preferences', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'legacy_access',
        'refresh_token': 'legacy_refresh',
      });

      await apiClient.loadToken();

      final prefs = await SharedPreferences.getInstance();
      expect(apiClient.token, 'legacy_access');
      expect(tokenStorage.values['auth_token'], 'legacy_access');
      expect(tokenStorage.values['refresh_token'], 'legacy_refresh');
      expect(prefs.containsKey('auth_token'), false);
      expect(prefs.containsKey('refresh_token'), false);
    });

    test('Should intercept and clear token gracefully', () async {
      await apiClient.saveToken('test_active_token');
      await apiClient.clearToken();

      expect(apiClient.token, isNull, reason: 'Token clear process failed!');
    });
  });
}
