/// Display-only current balance; money writes remain server-validated.
class OrderDebtBalance {
  final double total, paid, adjustment;
  final double? remaining;
  final String basis;
  final bool closedByAdjustment;
  const OrderDebtBalance._(
    this.total,
    this.paid,
    this.adjustment,
    this.remaining,
    this.basis,
    this.closedByAdjustment,
  );
  factory OrderDebtBalance.fromMap(
    Map<dynamic, dynamic> order, {
    bool purchase = false,
  }) {
    double? value(dynamic raw) {
      final v = num.tryParse('$raw');
      return v != null && v.isFinite ? v.toDouble() : null;
    }

    final total = value(order['totalAmount']),
        paid = value(order['paidAmount'] ?? order['amountPaid'] ?? 0);
    final adjustment = value(order['openingAdjustmentAmount'] ?? 0);
    final status = '${order['status']}'.toUpperCase();
    final returned = [
      'FULL_RETURN',
      'RETURNED',
    ].contains('${order['returnStatus']}');
    final basis = '${order['debtBalanceBasis'] ?? 'LEGACY_ORDER'}';
    final invalid =
        total == null ||
        total < 0 ||
        paid == null ||
        paid < 0 ||
        adjustment == null ||
        basis == 'RECONCILIATION_REQUIRED';
    if (invalid) {
      return OrderDebtBalance._(
        total ?? 0,
        paid ?? 0,
        adjustment ?? 0,
        null,
        'RECONCILIATION_REQUIRED',
        false,
      );
    }
    if (status == 'CANCELLED' || returned && basis != 'RETURN_LEDGER') {
      return OrderDebtBalance._(total, paid, adjustment, 0, 'CLOSED', false);
    }
    if (purchase && status != 'COMPLETED') {
      return OrderDebtBalance._(
        total,
        paid,
        adjustment,
        0,
        'NOT_POSTED',
        false,
      );
    }
    if (order['openingEffective'] == false) {
      return OrderDebtBalance._(
        total,
        paid,
        adjustment,
        0,
        'NOT_EFFECTIVE',
        false,
      );
    }
    final amount = order.containsKey('remainingAmount')
        ? value(order['remainingAmount'])
        : (total - paid + adjustment).clamp(0, double.infinity).toDouble();
    if (amount == null || amount < 0) {
      return OrderDebtBalance._(
        total,
        paid,
        adjustment,
        null,
        'RECONCILIATION_REQUIRED',
        false,
      );
    }
    return OrderDebtBalance._(
      total,
      paid,
      adjustment,
      amount,
      basis,
      order['closedByAdjustment'] == true ||
          amount == 0 && adjustment < 0 && paid < total,
    );
  }
  bool get canCollect =>
      remaining != null &&
      remaining! > 0 &&
      basis != 'NOT_POSTED' &&
      basis != 'CLOSED' &&
      basis != 'ORDER';
  bool get isInactive =>
      basis == 'NOT_POSTED' || basis == 'NOT_EFFECTIVE' || basis == 'CLOSED';
  String get label {
    if (remaining == null) return 'Cần đối chiếu';
    if (basis == 'NOT_POSTED') return 'Chưa ghi nhận công nợ';
    if (basis == 'NOT_EFFECTIVE') return 'Chưa đến ngày ghi nhận';
    if (basis == 'CLOSED') return 'Đã đóng công nợ';
    if (basis == 'ORDER' && (remaining ?? 0) > 0) {
      return 'Cần đối chiếu công nợ';
    }
    if (basis == 'RETURN_LEDGER') {
      return remaining == 0
          ? 'Đã hết nợ phí giao hàng'
          : 'Phí giao hàng còn nợ';
    }
    if (closedByAdjustment) return 'Hết nợ sau điều chỉnh';
    if (remaining == 0) return 'Đã thanh toán';
    return paid > 0 ? 'Thanh toán một phần' : 'Chưa thanh toán';
  }
}
