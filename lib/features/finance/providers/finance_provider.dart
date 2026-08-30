import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';

class FinanceRepository {
  final ApiClient _api;
  FinanceRepository(this._api);

  List<dynamic> _normalizeList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    if (value is Map) {
      final nested = value['items'] ?? value['data'];
      if (nested is List) return List<dynamic>.from(nested);
    }
    throw ApiException('Dữ liệu tài chính không hợp lệ');
  }

  Future<Map<String, dynamic>> findTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    String? category,
    String? from,
    String? to,
  }) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (type != null) params['type'] = type;
    if (category != null) params['category'] = category;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return _requirePagedResponse(
      await _api.get('/cash-transactions', params: params),
      'Dữ liệu giao dịch tài chính không hợp lệ',
      extraNumericFields: const ['filteredAmountTotal'],
    );
  }

  Future<Map<String, dynamic>> createTransaction(
    Map<String, dynamic> dto,
  ) async => await _api.post('/cash-transactions', data: dto);
  Future<Map<String, dynamic>> findTransaction(int id) async =>
      Map<String, dynamic>.from(await _api.get('/cash-transactions/$id'));
  Future<Map<String, dynamic>> updateTransaction(
    int id,
    Map<String, dynamic> dto,
  ) async => await _api.put('/cash-transactions/$id', data: dto);
  Future<void> deleteTransaction(int id) async =>
      await _api.delete('/cash-transactions/$id');

  Future<Map<String, dynamic>> getCashFlowSummary(
    String from,
    String to,
  ) async {
    final data = Map<String, dynamic>.from(
      await _api.get(
        '/cash-transactions/summary',
        params: {'from': from, 'to': to},
      ),
    );
    _requireNumericFields(data, const [
      'income',
      'expense',
      'netCashFlow',
      'cashBalance',
    ], 'tổng quan dòng tiền');
    if (data['dailyFlow'] is! List || data['period'] is! Map) {
      throw ApiException('Dữ liệu tổng quan dòng tiền không đầy đủ');
    }
    return data;
  }

  Future<Map<String, dynamic>> getProfitLoss(String from, String to) async {
    final data = Map<String, dynamic>.from(
      await _api.get(
        '/cash-transactions/profit-loss',
        params: {'from': from, 'to': to},
      ),
    );
    _requireNumericFields(data, const [
      'revenue',
      'cogs',
      'grossProfit',
      'operatingExpenses',
      'netProfit',
      'grossMarginPct',
      'netMarginPct',
    ], 'báo cáo lãi lỗ');
    if (data['from'] == null || data['to'] == null) {
      throw ApiException('Dữ liệu báo cáo lãi lỗ không đầy đủ');
    }
    return data;
  }

  void _requireNumericFields(
    Map<String, dynamic> data,
    List<String> keys,
    String label,
  ) {
    final invalid = keys.any((key) {
      final value = num.tryParse(data[key]?.toString() ?? '');
      return value == null || !value.isFinite;
    });
    if (invalid) throw ApiException('Dữ liệu $label không đầy đủ');
  }

  Future<Map<String, dynamic>> getInvoiceReconciliation({
    String? from,
    String? to,
    bool all = false,
  }) async {
    final params = <String, dynamic>{};
    if (all) {
      params['scope'] = 'ALL';
    } else {
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
    }
    return await _api.get(
      '/cash-transactions/invoice-reconciliation',
      params: params,
    );
  }

  Future<Map<String, dynamic>> getExpensesByCategory({
    String? from,
    String? to,
  }) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final data = await _api.get(
      '/cash-transactions/expenses-by-category',
      params: params,
    );
    if (data is! Map ||
        data['categories'] is! List ||
        data['recentItems'] is! List ||
        data['total'] is! num) {
      throw ApiException('Dữ liệu phân loại chi phí không đầy đủ');
    }
    final invalidCategory = (data['categories'] as List).any(
      (item) => item is! Map || item['amount'] is! num || item['count'] is! num,
    );
    if (invalidCategory) {
      throw ApiException('Dữ liệu phân loại chi phí không đầy đủ');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getDailyClosing(String date) async =>
      await _api.get('/daily-closings/$date');

  Future<Map<String, dynamic>> getDailyClosings({
    int page = 1,
    int limit = 20,
  }) async => _requirePagedResponse(
    await _api.get(
      '/daily-closings',
      params: {'page': '$page', 'limit': '$limit'},
    ),
    'Dữ liệu lịch sử chốt ngày không hợp lệ',
  );

  Future<Map<String, dynamic>> createDailyClosing(
    Map<String, dynamic> dto,
  ) async => await _api.post('/daily-closings', data: dto);

  Future<List<dynamic>> findAccounts() async =>
      _normalizeList(await _api.get('/cash-accounts'));

  Future<List<dynamic>> findForecasts({String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return _normalizeList(
      await _api.get('/cashflow-forecasts', params: params),
    );
  }

  Future<Map<String, dynamic>> createForecast(Map<String, dynamic> dto) async =>
      await _api.post('/cashflow-forecasts', data: dto);
  Future<Map<String, dynamic>> updateForecast(
    int id,
    Map<String, dynamic> dto,
  ) async => await _api.put('/cashflow-forecasts/$id', data: dto);
  Future<void> deleteForecast(int id) async =>
      await _api.delete('/cashflow-forecasts/$id');

  Future<List<dynamic>> findBudgetPlans() async =>
      _normalizeList(await _api.get('/budget-plans'));
  Future<Map<String, dynamic>> createBudgetPlan(
    Map<String, dynamic> dto,
  ) async => await _api.post('/budget-plans', data: dto);
  Future<Map<String, dynamic>> updateBudgetPlan(
    int id,
    Map<String, dynamic> dto,
  ) async => await _api.put('/budget-plans/$id', data: dto);
  Future<void> deleteBudgetPlan(int id) async =>
      await _api.delete('/budget-plans/$id');

  Future<Map<String, dynamic>> findInvoices({
    int page = 1,
    int limit = 20,
    String? type,
    String? from,
    String? to,
  }) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (type != null) params['type'] = type;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return _requirePagedResponse(
      await _api.get('/invoices', params: params),
      'Dữ liệu hóa đơn không hợp lệ',
    );
  }

  Future<Map<String, dynamic>> getInvoiceSummary(String from, String to) async {
    final data = await _api.get(
      '/invoices/summary',
      params: {'from': from, 'to': to},
    );
    if (data is! Map ||
        const [
          'vatIn',
          'vatOut',
          'vatOwed',
          'vatCredit',
        ].any((field) => data[field] is! num)) {
      throw ApiException('Dữ liệu tổng hợp hóa đơn không đầy đủ');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> findInvoiceById(int id) async =>
      await _api.get('/invoices/$id');
  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> dto) async =>
      await _api.post('/invoices', data: dto);
  Future<Map<String, dynamic>> updateInvoice(
    int id,
    Map<String, dynamic> dto,
  ) async => await _api.put('/invoices/$id', data: dto);
  Future<void> deleteInvoice(int id) async =>
      await _api.delete('/invoices/$id');

  Future<Map<String, dynamic>> findPurchasesNoInvoice({
    int page = 1,
    int limit = 20,
    String? status,
  }) async => await _api.get(
    '/purchases-without-invoice',
    params: {'page': '$page', 'limit': '$limit', 'status': ?status},
  );

  Future<Map<String, dynamic>> createPurchaseNoInvoice(
    Map<String, dynamic> dto,
  ) async => await _api.post('/purchases-without-invoice', data: dto);

  Future<Map<String, dynamic>> approvePurchaseNoInvoice(
    int id, {
    String? approvalNotes,
  }) async => await _api.post(
    '/purchases-without-invoice/$id/approve',
    data: {'approvalNotes': approvalNotes},
  );

  Future<Map<String, dynamic>> rejectPurchaseNoInvoice(
    int id, {
    String? approvalNotes,
  }) async => await _api.post(
    '/purchases-without-invoice/$id/reject',
    data: {'approvalNotes': approvalNotes},
  );

  // Tax Obligations
  Future<Map<String, dynamic>> getTaxObligations() async =>
      await _api.get('/tax-obligations');
  Future<Map<String, dynamic>> createTaxObligation(
    Map<String, dynamic> dto,
  ) async => await _api.post('/tax-obligations', data: dto);
  Future<Map<String, dynamic>> updateTaxObligation(
    int id,
    Map<String, dynamic> dto,
  ) async => await _api.put('/tax-obligations/$id', data: dto);
  Future<void> deleteTaxObligation(int id) async =>
      await _api.delete('/tax-obligations/$id');
}

Map<String, dynamic> _requirePagedResponse(
  dynamic data,
  String message, {
  List<String> extraNumericFields = const [],
}) {
  if (data is! Map ||
      data['items'] is! List ||
      data['total'] is! num ||
      data['page'] is! num ||
      data['limit'] is! num ||
      data['totalPages'] is! num ||
      extraNumericFields.any((field) => data[field] is! num)) {
    throw ApiException(message);
  }
  return Map<String, dynamic>.from(data);
}

final financeRepoProvider = Provider<FinanceRepository>((ref) {
  ref.watch(shopProvider);
  return FinanceRepository(ref.read(apiClientProvider));
});

final transactionsProvider =
    FutureProvider.family<
      Map<String, dynamic>,
      ({
        int page,
        int limit,
        String? type,
        String? category,
        String? from,
        String? to,
      })
    >((ref, args) {
      return ref
          .watch(financeRepoProvider)
          .findTransactions(
            page: args.page,
            limit: args.limit,
            type: args.type,
            category: args.category,
            from: args.from,
            to: args.to,
          );
    });

final transactionDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) {
      return ref.watch(financeRepoProvider).findTransaction(id);
    });

final cashSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, ({String from, String to})>((
      ref,
      args,
    ) {
      return ref
          .watch(financeRepoProvider)
          .getCashFlowSummary(args.from, args.to);
    });

final profitLossProvider =
    FutureProvider.family<Map<String, dynamic>, ({String from, String to})>((
      ref,
      args,
    ) {
      return ref.watch(financeRepoProvider).getProfitLoss(args.from, args.to);
    });

final invoiceReconciliationProvider =
    FutureProvider.family<
      Map<String, dynamic>,
      ({String? from, String? to, bool all})
    >((ref, args) {
      return ref
          .watch(financeRepoProvider)
          .getInvoiceReconciliation(
            from: args.from,
            to: args.to,
            all: args.all,
          );
    });

final expensesByCategoryProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(financeRepoProvider).getExpensesByCategory();
});

final expensesByCategoryForPeriodProvider =
    FutureProvider.family<Map<String, dynamic>, ({String from, String to})>((
      ref,
      args,
    ) {
      return ref
          .watch(financeRepoProvider)
          .getExpensesByCategory(from: args.from, to: args.to);
    });

final dailyClosingProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, date) {
      return ref.watch(financeRepoProvider).getDailyClosing(date);
    });

final dailyClosingsListProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, page) {
      return ref.watch(financeRepoProvider).getDailyClosings(page: page);
    });

final cashAccountsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(financeRepoProvider).findAccounts();
});

final forecastsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(financeRepoProvider).findForecasts();
});

final budgetPlansProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(financeRepoProvider).findBudgetPlans();
});

final invoiceListProvider =
    FutureProvider.family<
      Map<String, dynamic>,
      ({int page, String? type, String? from, String? to})
    >((ref, args) {
      return ref
          .watch(financeRepoProvider)
          .findInvoices(
            page: args.page,
            type: args.type,
            from: args.from,
            to: args.to,
          );
    });

final invoiceSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, ({String from, String to})>((
      ref,
      args,
    ) {
      return ref
          .watch(financeRepoProvider)
          .getInvoiceSummary(args.from, args.to);
    });

final purchasesNoInvoiceProvider =
    FutureProvider.family<Map<String, dynamic>, ({int page, String? status})>((
      ref,
      args,
    ) {
      return ref
          .watch(financeRepoProvider)
          .findPurchasesNoInvoice(page: args.page, status: args.status);
    });

final taxObligationsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(financeRepoProvider).getTaxObligations();
});
