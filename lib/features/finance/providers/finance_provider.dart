import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class FinanceRepository {
  final ApiClient _api;
  FinanceRepository(this._api);

  Future<Map<String, dynamic>> findTransactions({int page = 1, int limit = 20, String? type, String? from, String? to}) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (type != null) params['type'] = type;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return await _api.get('/cash-transactions', params: params);
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> dto) async => await _api.post('/cash-transactions', data: dto);

  Future<Map<String, dynamic>> getCashFlowSummary(String from, String to) async =>
      await _api.get('/cash-transactions/summary', params: {'from': from, 'to': to});

  Future<Map<String, dynamic>> getProfitLoss(String from, String to) async =>
      await _api.get('/cash-transactions/profit-loss', params: {'from': from, 'to': to});

  Future<Map<String, dynamic>> getExpensesByCategory({String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return await _api.get('/cash-transactions/expenses-by-category', params: params);
  }

  Future<Map<String, dynamic>> getDailyClosing(String date) async =>
      await _api.get('/daily-closings/$date');

  Future<Map<String, dynamic>> getDailyClosings({int page = 1, int limit = 20}) async =>
      await _api.get('/daily-closings', params: {'page': '$page', 'limit': '$limit'});

  Future<Map<String, dynamic>> createDailyClosing(Map<String, dynamic> dto) async =>
      await _api.post('/daily-closings', data: dto);

  Future<List<dynamic>> findAccounts() async => await _api.get('/cash-accounts');

  Future<List<dynamic>> findForecasts({String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return await _api.get('/cashflow-forecasts', params: params);
  }

  Future<Map<String, dynamic>> createForecast(Map<String, dynamic> dto) async => await _api.post('/cashflow-forecasts', data: dto);
  Future<Map<String, dynamic>> updateForecast(int id, Map<String, dynamic> dto) async => await _api.put('/cashflow-forecasts/$id', data: dto);
  Future<void> deleteForecast(int id) async => await _api.delete('/cashflow-forecasts/$id');

  Future<List<dynamic>> findBudgetPlans() async => await _api.get('/budget-plans');
  Future<Map<String, dynamic>> createBudgetPlan(Map<String, dynamic> dto) async => await _api.post('/budget-plans', data: dto);
  Future<Map<String, dynamic>> updateBudgetPlan(int id, Map<String, dynamic> dto) async => await _api.put('/budget-plans/$id', data: dto);
  Future<void> deleteBudgetPlan(int id) async => await _api.delete('/budget-plans/$id');

  Future<Map<String, dynamic>> findInvoices({int page = 1, int limit = 20, String? type, String? from, String? to}) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (type != null) params['type'] = type;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return await _api.get('/invoices', params: params);
  }

  Future<Map<String, dynamic>> getInvoiceSummary(String from, String to) async =>
      await _api.get('/invoices/summary', params: {'from': from, 'to': to});

  Future<Map<String, dynamic>> findInvoiceById(int id) async => await _api.get('/invoices/$id');
  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> dto) async => await _api.post('/invoices', data: dto);

  Future<Map<String, dynamic>> findPurchasesNoInvoice({int page = 1, int limit = 20}) async =>
      await _api.get('/purchases-without-invoice', params: {'page': '$page', 'limit': '$limit'});

  Future<Map<String, dynamic>> createPurchaseNoInvoice(Map<String, dynamic> dto) async =>
      await _api.post('/purchases-without-invoice', data: dto);

  // Tax Obligations
  Future<Map<String, dynamic>> getTaxObligations() async => await _api.get('/tax-obligations');
  Future<Map<String, dynamic>> createTaxObligation(Map<String, dynamic> dto) async => await _api.post('/tax-obligations', data: dto);
}

final financeRepoProvider = Provider<FinanceRepository>((ref) => FinanceRepository(ref.read(apiClientProvider)));

final transactionsProvider = FutureProvider.family<Map<String, dynamic>, ({int page, String? type, String? from, String? to})>((ref, args) {
  return ref.read(financeRepoProvider).findTransactions(page: args.page, type: args.type, from: args.from, to: args.to);
});

final cashSummaryProvider = FutureProvider.family<Map<String, dynamic>, ({String from, String to})>((ref, args) {
  return ref.read(financeRepoProvider).getCashFlowSummary(args.from, args.to);
});

final profitLossProvider = FutureProvider.family<Map<String, dynamic>, ({String from, String to})>((ref, args) {
  return ref.read(financeRepoProvider).getProfitLoss(args.from, args.to);
});

final expensesByCategoryProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.read(financeRepoProvider).getExpensesByCategory();
});

final dailyClosingProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, date) {
  return ref.read(financeRepoProvider).getDailyClosing(date);
});

final dailyClosingsListProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, page) {
  return ref.read(financeRepoProvider).getDailyClosings(page: page);
});

final cashAccountsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.read(financeRepoProvider).findAccounts();
});

final forecastsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.read(financeRepoProvider).findForecasts();
});

final budgetPlansProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.read(financeRepoProvider).findBudgetPlans();
});

final invoiceListProvider = FutureProvider.family<Map<String, dynamic>, ({int page, String? type})>((ref, args) {
  return ref.read(financeRepoProvider).findInvoices(page: args.page, type: args.type);
});

final invoiceSummaryProvider = FutureProvider.family<Map<String, dynamic>, ({String from, String to})>((ref, args) {
  return ref.read(financeRepoProvider).getInvoiceSummary(args.from, args.to);
});

final purchasesNoInvoiceProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, page) {
  return ref.read(financeRepoProvider).findPurchasesNoInvoice(page: page);
});


final taxObligationsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.read(financeRepoProvider).getTaxObligations();
});
