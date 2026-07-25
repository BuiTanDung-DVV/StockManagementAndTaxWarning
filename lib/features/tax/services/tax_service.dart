import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';

class TaxService {
  final ApiClient _apiClient;

  TaxService(this._apiClient);

  Future<Map<String, dynamic>> getTaxEstimate(
    String period,
    String year,
  ) async {
    try {
      final data = await _apiClient.get(
        '/tax/estimate',
        params: {'period': period, 'year': year},
      );
      return data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Không thể lấy lịch sử thuế: $e');
    }
  }

  Future<void> exportHTKK(String period, String year) async {
    try {
      // Tải bằng API client để token chỉ nằm trong Authorization header,
      // không xuất hiện trong URL, lịch sử trình duyệt hoặc log máy chủ.
      final response = await _apiClient.dio.get<String>(
        'tax/export-htkk',
        queryParameters: {'period': period, 'year': year},
        options: Options(responseType: ResponseType.plain),
      );
      final xml = response.data;
      if (xml == null || xml.trim().isEmpty) {
        throw Exception('Máy chủ không trả về nội dung XML');
      }
      final uri = Uri.dataFromString(xml, mimeType: 'text/xml', encoding: utf8);
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
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
