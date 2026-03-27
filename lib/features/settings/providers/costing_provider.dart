import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class CostingState {
  final String method; // 'FIFO' | 'AVG'
  final bool isLoading;

  const CostingState({this.method = 'AVG', this.isLoading = false});

  CostingState copyWith({String? method, bool? isLoading}) => CostingState(
    method: method ?? this.method,
    isLoading: isLoading ?? this.isLoading,
  );
}

class CostingNotifier extends Notifier<CostingState> {
  @override
  CostingState build() => const CostingState();

  ApiClient get _api => ref.read(apiClientProvider);

  /// Fetch current costing method from server
  Future<void> loadCostingMethod() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.get('/cogs/method');
      state = state.copyWith(
        method: (data is Map && data['method'] != null) ? data['method'].toString() : 'AVG',
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Update costing method on server
  Future<bool> updateCostingMethod(String method) async {
    state = state.copyWith(isLoading: true);
    try {
      await _api.put('/system/shop-profile/1', data: {'costingMethod': method});
      state = state.copyWith(method: method, isLoading: false);
      return true;
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  /// Get inventory lots for a product
  Future<List<Map<String, dynamic>>> getProductLots(int productId) async {
    try {
      final data = await _api.get('/cogs/lots/$productId');
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get inventory valuation
  Future<Map<String, dynamic>> getValuation({int? productId}) async {
    try {
      final params = <String, dynamic>{};
      if (productId != null) params['productId'] = productId;
      final data = await _api.get('/cogs/valuation', params: params);
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } catch (_) {
      return {};
    }
  }
}

final costingProvider = NotifierProvider<CostingNotifier, CostingState>(CostingNotifier.new);
