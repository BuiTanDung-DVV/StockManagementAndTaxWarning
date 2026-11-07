/// A complete, validated ledger read from one server response, never assembled
/// from the currently visible page. Amounts use integer cents for control totals.
class CashLedgerExport {
  final int shopId;
  final String from;
  final String to;
  final String? type;
  final String? category;
  final List<Map<String, dynamic>> items;
  final int incomeCents;
  final int expenseCents;

  const CashLedgerExport._(
    this.shopId,
    this.from,
    this.to,
    this.type,
    this.category,
    this.items,
    this.incomeCents,
    this.expenseCents,
  );

  static Never _invalid() => throw const FormatException(
    'Dữ liệu xuất sổ thu chi không đầy đủ hoặc không khớp phạm vi.',
  );

  static int cents(dynamic value, {bool signed = false}) {
    final text = value?.toString() ?? '';
    if (!(signed
            ? RegExp(r'^-?\d+(?:\.\d{1,2})?$')
            : RegExp(r'^\d+(?:\.\d{1,2})?$'))
        .hasMatch(text)) {
      _invalid();
    }
    final parts = text.replaceFirst('-', '').split('.');
    final result =
        int.parse(parts[0]) * 100 +
        int.parse(parts.length == 1 ? '00' : parts[1].padRight(2, '0'));
    if (result > 9007199254740991) _invalid();
    return text.startsWith('-') ? -result : result;
  }

  static bool validDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    return DateTime.tryParse(value)?.toIso8601String().split('T').first ==
        value;
  }

  factory CashLedgerExport.fromResponse(
    dynamic raw, {
    required int shopId,
    required String from,
    required String to,
    String? type,
    String? category,
  }) {
    if (raw is! Map ||
        raw['shopId'] != shopId ||
        !validDate(from) ||
        !validDate(to) ||
        from.compareTo(to) > 0) {
      _invalid();
    }
    final period = raw['period'];
    final filters = raw['filters'];
    final summary = raw['summary'];
    final rows = raw['items'];
    if (period is! Map ||
        filters is! Map ||
        summary is! Map ||
        rows is! List ||
        period['from'] != from ||
        period['to'] != to ||
        period['dateField'] != 'transactionDate' ||
        filters['type'] != type ||
        filters['category'] != category ||
        summary['recordCount'] != rows.length) {
      _invalid();
    }
    final items = <Map<String, dynamic>>[];
    final ids = <int>{};
    int income = 0;
    int expense = 0;
    for (final row in rows) {
      if (row is! Map ||
          row['id'] is! int ||
          (row['id'] as int) <= 0 ||
          !ids.add(row['id']) ||
          row['shopId'] != shopId ||
          !const {'INCOME', 'EXPENSE'}.contains(row['type']) ||
          (type != null && row['type'] != type) ||
          (category != null && row['category'] != category)) {
        _invalid();
      }
      final date = row['transactionDate']?.toString() ?? '';
      if (!validDate(date) ||
          date.compareTo(from) < 0 ||
          date.compareTo(to) > 0) {
        _invalid();
      }
      final amount = cents(row['amount']);
      if (row['type'] == 'INCOME') {
        income += amount;
      } else {
        expense += amount;
      }
      if (income > 9007199254740991 || expense > 9007199254740991) _invalid();
      items.add(
        Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(row)),
      );
    }
    if (cents(summary['income']) != income ||
        cents(summary['expense']) != expense ||
        cents(summary['netCashFlow'], signed: true) != income - expense) {
      _invalid();
    }
    return CashLedgerExport._(
      shopId,
      from,
      to,
      type,
      category,
      List.unmodifiable(items),
      income,
      expense,
    );
  }

  static String decimalAmount(int cents) {
    final amount = cents.abs();
    return '${cents < 0 ? '-' : ''}${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
  }
}
