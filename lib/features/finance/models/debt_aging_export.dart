import 'cash_ledger_export.dart';

/// One complete server snapshot. The grouping day does not turn current debt
/// into a historical balance.
class DebtAgingExport {
  final int shopId;
  final String asOf;
  final DateTime balanceAsOf;
  final List<Map<String, dynamic>> customers;
  final Map<String, int> bucketCents;
  final int totalCents;
  final int receivableCount;
  const DebtAgingExport._(
    this.shopId,
    this.asOf,
    this.balanceAsOf,
    this.customers,
    this.bucketCents,
    this.totalCents,
    this.receivableCount,
  );
  static Never _invalid() => throw const FormatException(
    'Dữ liệu xuất tuổi nợ không đầy đủ hoặc không khớp tổng.',
  );
  static String businessDay(String value) {
    if (value.length < 10 ||
        !CashLedgerExport.validDate(value.substring(0, 10))) {
      _invalid();
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) _invalid();
    final date = parsed.isUtc ? parsed.add(const Duration(hours: 7)) : parsed;
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  factory DebtAgingExport.fromResponse(
    dynamic raw, {
    required int shopId,
    required String asOf,
  }) {
    if (shopId <= 0 ||
        !CashLedgerExport.validDate(asOf) ||
        raw is! Map ||
        raw['balanceBasis'] != 'CURRENT' ||
        raw['asOf'] is! String ||
        businessDay(raw['asOf']) != asOf ||
        raw['summary'] is! Map ||
        raw['buckets'] is! Map ||
        raw['customers'] is! List) {
      _invalid();
    }
    final snapshot = raw['balanceAsOf'];
    if (snapshot is! String ||
        !(CashLedgerExport.validDate(snapshot) ||
            (snapshot.contains('T') &&
                RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(snapshot)))) {
      _invalid();
    }
    businessDay(snapshot);
    final balanceAsOf = DateTime.tryParse(snapshot);
    if (balanceAsOf == null) _invalid();
    final summary = raw['summary'] as Map;
    final buckets = raw['buckets'] as Map;
    const keys = ['current', 'past30', 'past60', 'past90'];
    final amounts = {
      for (final key in keys) key: CashLedgerExport.cents(buckets[key]),
    };
    final total = CashLedgerExport.cents(raw['totalDebt']);
    if (CashLedgerExport.cents(summary['totalDebt']) != total ||
        amounts.values.fold(0, (int a, int b) => a + b) != total ||
        CashLedgerExport.cents(summary['overdueDebt']) !=
            amounts['past30']! + amounts['past60']! + amounts['past90']!) {
      _invalid();
    }
    final customers = <Map<String, dynamic>>[];
    final ids = <int>{};
    final sums = {for (final key in keys) key: 0};
    var controlTotal = 0;
    for (final item in raw['customers'] as List) {
      if (item is! Map ||
          item['customerId'] is! int ||
          item['customerId'] < 0 ||
          !ids.add(item['customerId']) ||
          item['customerName'] is! String ||
          (item['customerName'] as String).trim().isEmpty ||
          item['overdueDays'] is! int ||
          item['overdueDays'] < 0) {
        _invalid();
      }
      final values = {
        for (final key in keys) key: CashLedgerExport.cents(item[key]),
      };
      final rowTotal = CashLedgerExport.cents(item['total']);
      if (rowTotal <= 0) _invalid();
      final overdue = CashLedgerExport.cents(item['overdue']);
      if (values.values.fold(0, (int a, int b) => a + b) != rowTotal ||
          overdue != rowTotal - values['current']!) {
        _invalid();
      }
      if ((overdue > 0) != (item['overdueDays'] > 0)) _invalid();
      final payment = item['lastPaymentDate'];
      if (payment != null) {
        if (payment is! String) _invalid();
        businessDay(payment);
      }
      for (final key in keys) {
        sums[key] = sums[key]! + values[key]!;
      }
      controlTotal += rowTotal;
      if (controlTotal > 9007199254740991) _invalid();
      customers.add(
        Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(item)),
      );
    }
    for (final key in keys) {
      if (sums[key] != amounts[key]) _invalid();
    }
    final count = raw['receivableCount'];
    if (controlTotal != total ||
        raw['customerCount'] != customers.length ||
        summary['customerCount'] != customers.length ||
        count is! int ||
        count < customers.length ||
        (customers.isEmpty && count != 0) ||
        summary['receivableCount'] != count) {
      _invalid();
    }
    return DebtAgingExport._(
      shopId,
      asOf,
      balanceAsOf,
      List.unmodifiable(customers),
      Map.unmodifiable(amounts),
      total,
      count,
    );
  }
}
