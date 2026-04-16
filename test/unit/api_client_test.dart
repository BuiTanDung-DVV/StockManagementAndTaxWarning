import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/network/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('ApiClient Tests', () {
    late ApiClient apiClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      apiClient = ApiClient();
    });

    test('baseUrl should point to vercel deployment', () {
      expect(ApiClient.baseUrl.contains('vercel.app'), true, 
        reason: 'API URL phải được cấu hình trỏ về Vercel');
    });

    test('Should persist and load auth token securely', () async {
      await apiClient.saveToken('test_fake_token_123');
      await apiClient.loadToken();
      
      expect(apiClient.token, 'test_fake_token_123', 
        reason: 'Token save/load process failed!');
    });

    test('Should intercept and clear token gracefully', () async {
      await apiClient.saveToken('test_active_token');
      await apiClient.clearToken();
      
      expect(apiClient.token, isNull, 
        reason: 'Token clear process failed!');
    });
  });
}
