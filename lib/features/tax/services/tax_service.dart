import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';

class TaxService {
  final ApiClient _apiClient;

  TaxService(this._apiClient);

  Future<Map<String, dynamic>> getTaxEstimate(String period, String year) async {
    try {
      final data = await _apiClient.get(
        '/tax/estimate',
        params: {
          'period': period,
          'year': year,
        },
      );
      return data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Không thể lấy lịch sử thuế: $e');
    }
  }

  Future<void> exportHTKK(String period, String year) async {
    final token = _apiClient.token;
    final shopId = _apiClient.shopId;
    final urlString = '${ApiClient.baseUrl}/tax/export-htkk?period=$period&year=$year&token=$token&shopId=$shopId';
    final url = Uri.parse(urlString);
    
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
         throw Exception('Trình duyệt đã chặn tải xuống');
      }
    } catch (e) {
      throw Exception('Không thể tải file: $e');
    }
  }
}

final taxServiceProvider = Provider<TaxService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TaxService(apiClient);
});
