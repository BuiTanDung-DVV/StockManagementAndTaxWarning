import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class CostingState {
  final String? method; // 'FIFO' | 'AVG', null khi chưa tải được từ DB
  final bool isLoading;
  final String? errorMessage;

  const CostingState({this.method, this.isLoading = false, this.errorMessage});

  bool get hasData => method == 'AVG' || method == 'FIFO';
}

class CostingNotifier extends Notifier<CostingState> {
  @override
  CostingState build() => const CostingState(isLoading: true);

  ApiClient get _api => ref.read(apiClientProvider);

  /// Fetch current costing method from server
  Future<void> loadCostingMethod() async {
    state = const CostingState(isLoading: true);
    try {
      final data = await _api.get('/cogs/method');
      final method = data is Map ? data['method']?.toString() : null;
      if (method != 'AVG' && method != 'FIFO') {
        throw const FormatException(
          'Phương pháp tính giá vốn từ API không hợp lệ',
        );
      }
      state = CostingState(method: method);
    } catch (e) {
      debugPrint('CostingProvider.loadCostingMethod error: $e');
      state = const CostingState(
        errorMessage:
            'Không thể tải phương pháp tính giá vốn từ cơ sở dữ liệu.',
      );
    }
  }

  /// Update costing method on server
  Future<bool> updateCostingMethod(String method) async {
    if (method != 'AVG' && method != 'FIFO') return false;
    final previous = state;
    state = CostingState(method: previous.method, isLoading: true);
    try {
      await _api.post('/shop-profile', data: {'costingMethod': method});
      state = CostingState(method: method);
      return true;
    } catch (e) {
      debugPrint('CostingProvider.updateCostingMethod error: $e');
      state = CostingState(
        method: previous.method,
        errorMessage: 'Không thể lưu phương pháp tính giá vốn.',
      );
      return false;
    }
  }

  /// Get inventory lots for a product
  Future<List<Map<String, dynamic>>> getProductLots(int productId) async {
    final data = await _api.get('/cogs/lots/$productId');
    if (data is! List) {
      throw const FormatException('Danh sách lô tồn từ API không hợp lệ');
    }
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Get inventory valuation
  Future<Map<String, dynamic>> getValuation({int? productId}) async {
    final params = <String, dynamic>{};
    if (productId != null) params['productId'] = productId;
    final data = await _api.get('/cogs/valuation', params: params);
    if (data is! Map) {
      throw const FormatException('Giá trị tồn kho từ API không hợp lệ');
    }
    return Map<String, dynamic>.from(data);
  }
}

final costingProvider = NotifierProvider<CostingNotifier, CostingState>(
  CostingNotifier.new,
);
