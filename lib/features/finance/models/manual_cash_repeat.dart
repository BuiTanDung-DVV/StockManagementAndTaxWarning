/// Only standalone cash records can be reused. Source-linked movements must be
/// created from their purchase, sale, debt or tax workflow.
class ManualCashRepeat {
  final String type;
  final String category;
  final double amount;
  final String counterparty;
  final String notes;
  final String? paymentMethod;
  final int? shopId;

  const ManualCashRepeat._({
    required this.type,
    required this.category,
    required this.amount,
    required this.counterparty,
    required this.notes,
    required this.paymentMethod,
    required this.shopId,
  });

  static ManualCashRepeat? from(Map<dynamic, dynamic> source) {
    final type = '${source['type'] ?? ''}'.trim().toUpperCase();
    final category = '${source['category'] ?? ''}'.trim().toUpperCase();
    final reference = '${source['referenceType'] ?? ''}'.trim().toUpperCase();
    final amount = double.tryParse('${source['amount']}');
    if (!const {'INCOME', 'EXPENSE'}.contains(type) ||
        category.isEmpty ||
        category.length > 50 ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        (reference.isNotEmpty && reference != 'CASH_TRANSACTION') ||
        const {
          'PURCHASE',
          'SALES',
          'SALES_RETURN',
          'DEBT_COLLECTION',
          'DEBT_PAYMENT',
          'TAX',
        }.contains(category)) {
      return null;
    }
    final rawMethod = '${source['paymentMethod'] ?? ''}'.trim().toUpperCase();
    final method = switch (rawMethod) {
      'BANK_TRANSFER' => 'TRANSFER',
      'CREDIT_CARD' => 'CARD',
      'CASH' ||
      'TRANSFER' ||
      'QR' ||
      'CARD' ||
      'MOMO' ||
      'ZALOPAY' => rawMethod,
      _ => null,
    };
    return ManualCashRepeat._(
      type: type,
      category: category,
      amount: amount,
      counterparty: '${source['counterparty'] ?? ''}',
      notes: '${source['notes'] ?? source['description'] ?? ''}',
      paymentMethod: method,
      shopId: int.tryParse('${source['shopId']}'),
    );
  }

  Map<String, dynamic> payload({
    required double amount,
    required DateTime date,
    required String method,
    required String counterparty,
    required String notes,
  }) => {
    'type': type,
    'category': category,
    'amount': amount,
    'transactionDate':
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'paymentMethod': method,
    'counterparty': counterparty.trim(),
    'notes': notes.trim(),
  };
}
