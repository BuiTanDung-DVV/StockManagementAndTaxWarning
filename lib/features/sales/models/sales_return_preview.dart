import '../../../core/utils/order_debt_balance.dart';

class SalesReturnPreview {
  final double paid,
      refund,
      shipping,
      retainedCash,
      adjustmentForShipping,
      remaining;
  const SalesReturnPreview(
    this.paid,
    this.refund,
    this.shipping,
    this.retainedCash,
    this.adjustmentForShipping,
    this.remaining,
  );

  factory SalesReturnPreview.fromOrder(
    Map<String, dynamic> order,
    bool refundShipping, {
    Map<int, int>? quantities,
  }) {
    final lines = returnableSalesLines(order);
    final selected =
        quantities ??
        {
          for (final line in lines)
            if (line.remaining > 0) line.productId: line.remaining,
        };
    if (selected.isEmpty || selected.values.every((q) => q == 0)) {
      throw const FormatException('Chọn ít nhất một mặt hàng và số lượng trả.');
    }
    double value(String key) {
      final n = num.tryParse('${order[key] ?? 0}');
      if (n == null || !n.isFinite || n < 0) {
        throw const FormatException('Số tiền trên đơn cần đối chiếu');
      }
      return n.toDouble();
    }

    double cents(double amount) => double.parse(amount.toStringAsFixed(2));
    final debt = OrderDebtBalance.fromMap(order);
    if (debt.remaining == null || debt.adjustment > 0) {
      throw const FormatException('Công nợ cần đối chiếu trước khi trả hàng');
    }
    final sorted = [...lines]
      ..sort((a, b) => a.productId.compareTo(b.productId));
    final gross = sorted.map((l) => _returnCents(l.item['subtotal'])).toList();
    final subtotal = _returnCents(order['subtotal']);
    final discount = _returnCents(order['discountAmount'] ?? 0);
    final tax = _returnCents(order['taxAmount'] ?? 0);
    if (gross.fold(BigInt.zero, (a, b) => a + b) != subtotal ||
        discount > subtotal) {
      throw const FormatException('Tiền hàng cần đối chiếu.');
    }
    final discounts = _returnAllocate(discount, gross);
    final taxWeights = sorted
        .map((l) => _returnCents(l.item['taxAmount'] ?? 0))
        .toList();
    final taxes = _returnAllocate(
      tax,
      taxWeights.any((v) => v > BigInt.zero) ? taxWeights : gross,
    );
    var goodsCents = BigInt.zero;
    for (var i = 0; i < sorted.length; i++) {
      final line = sorted[i], q = selected[sorted[i].productId] ?? 0;
      if (q < 0 || q > line.remaining) {
        throw const FormatException(
          'Số lượng trả vượt phần hàng còn được trả.',
        );
      }
      final net = gross[i] - discounts[i];
      goodsCents +=
          _returnRatio(net, line.returned + q, line.sold) -
          _returnRatio(net, line.returned, line.sold) +
          _returnRatio(taxes[i], line.returned + q, line.sold) -
          _returnRatio(taxes[i], line.returned, line.sold);
    }
    if (selected.keys.any((id) => !lines.any((line) => line.productId == id))) {
      throw const FormatException('Mặt hàng trả không thuộc đơn.');
    }
    final goods = goodsCents.toDouble() / 100;
    final fee = order['shippingFeePayer'] == 'CUSTOMER'
        ? cents(value('shippingFee') * (1 + value('shippingTaxRate') / 100))
        : 0.0;
    final previous = (order['returns'] as List? ?? []).whereType<Map>().where(
      (r) => r['status'] == 'COMPLETED',
    );
    final feeRefunded = previous.any((r) => r['refundShippingFee'] == true);
    if (feeRefunded && refundShipping) {
      throw const FormatException('Phí giao đã được hoàn trong phiếu trước.');
    }
    final refunded = previous.fold<BigInt>(
      BigInt.zero,
      (a, r) => a + _returnCents(r['refundAmount']),
    );
    final paid = value('paidAmount');
    final paidCents = _returnCents(paid);
    if (refunded > paidCents) {
      throw const FormatException('Tiền đã hoàn cần đối chiếu.');
    }
    final reversal = cents(goods + (refundShipping ? fee : 0));
    final available = paidCents - refunded;
    final reversed = _returnCents(reversal);
    final refundCents = available < reversed ? available : reversed;
    final refund = refundCents.toDouble() / 100;
    final kept = (available - refundCents).toDouble() / 100;
    final retainedFee = refundShipping || feeRefunded ? 0.0 : fee;
    final remaining = cents(
      (debt.remaining! - (reversal - refund)).clamp(0, double.infinity),
    );
    final allReturned = lines.every(
      (l) => (selected[l.productId] ?? 0) == l.remaining,
    );
    final rawShipping = cents((retainedFee - kept).clamp(0, double.infinity));
    final applied = allReturned
        ? cents(
            (rawShipping - remaining).clamp(
              0.0,
              debt.adjustment < 0 ? -debt.adjustment : 0.0,
            ),
          )
        : 0.0;
    return SalesReturnPreview(
      paid,
      refund,
      retainedFee,
      kept,
      applied,
      remaining,
    );
  }
}

class ReturnableSalesLine {
  final int productId, sold, returned;
  final Map<String, dynamic> item;
  int get remaining => sold - returned;
  const ReturnableSalesLine(
    this.productId,
    this.sold,
    this.returned,
    this.item,
  );
}

List<ReturnableSalesLine> returnableSalesLines(Map<String, dynamic> order) {
  final previous = <int, int>{};
  for (final row in (order['returns'] as List? ?? []).whereType<Map>().where(
    (r) => r['status'] == 'COMPLETED',
  )) {
    if (row['items'] is! List) {
      throw const FormatException('Thiếu chi tiết hàng đã trả. Tải lại đơn.');
    }
    for (final item in (row['items'] as List).whereType<Map>()) {
      final id = int.tryParse('${item['productId'] ?? item['product']?['id']}');
      final qty = int.tryParse('${item['quantity']}');
      if (id == null || qty == null || qty <= 0) {
        throw const FormatException('Lịch sử trả hàng cần đối chiếu.');
      }
      previous[id] = (previous[id] ?? 0) + qty;
    }
  }
  final result = <ReturnableSalesLine>[];
  for (final raw in (order['items'] as List? ?? [])) {
    if (raw is! Map) {
      throw const FormatException('Chi tiết hàng bán không hợp lệ.');
    }
    final id = int.tryParse('${raw['productId'] ?? raw['product']?['id']}');
    final sold = int.tryParse('${raw['quantity']}');
    if (id == null ||
        id <= 0 ||
        sold == null ||
        sold <= 0 ||
        (previous[id] ?? 0) > sold ||
        result.any((l) => l.productId == id)) {
      throw const FormatException('Số lượng hàng bán/đã trả cần đối chiếu.');
    }
    result.add(
      ReturnableSalesLine(
        id,
        sold,
        previous[id] ?? 0,
        Map<String, dynamic>.from(raw),
      ),
    );
  }
  if (result.isEmpty ||
      previous.keys.any((id) => !result.any((l) => l.productId == id))) {
    throw const FormatException('Thiếu chi tiết hàng bán.');
  }
  return result;
}

BigInt _returnCents(dynamic raw) {
  final n = num.tryParse('$raw');
  if (n == null || !n.isFinite || n < 0) {
    throw const FormatException('Giá trị tiền cần đối chiếu.');
  }
  return BigInt.parse(n.toStringAsFixed(2).replaceAll('.', ''));
}

BigInt _returnRatio(BigInt amount, int n, int d) =>
    (amount * BigInt.from(n) * BigInt.two + BigInt.from(d)) ~/
    (BigInt.from(d) * BigInt.two);
List<BigInt> _returnAllocate(BigInt amount, List<BigInt> weights) {
  final total = weights.fold(BigInt.zero, (a, b) => a + b);
  if (total == BigInt.zero) {
    if (amount != BigInt.zero) {
      throw const FormatException('Giá trị phân bổ cần đối chiếu.');
    }
    return weights.map((_) => BigInt.zero).toList();
  }
  final shares = weights.map((w) => amount * w ~/ total).toList();
  final order = List.generate(weights.length, (i) => i)
    ..sort(
      (a, b) =>
          (amount * weights[b] % total).compareTo(
                amount * weights[a] % total,
              ) ==
              0
          ? a.compareTo(b)
          : (amount * weights[b] % total).compareTo(
              amount * weights[a] % total,
            ),
    );
  var left = amount - shares.fold(BigInt.zero, (a, b) => a + b);
  for (final i in order) {
    if (left <= BigInt.zero) break;
    shares[i] += BigInt.one;
    left -= BigInt.one;
  }
  return shares;
}
