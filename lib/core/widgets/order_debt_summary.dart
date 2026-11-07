import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/order_debt_balance.dart';

class OrderDebtSummary extends StatelessWidget {
  final Map<dynamic, dynamic> order;
  final bool purchase;
  const OrderDebtSummary({
    super.key,
    required this.order,
    this.purchase = false,
  });
  @override
  Widget build(BuildContext context) {
    final balance = OrderDebtBalance.fromMap(order, purchase: purchase);
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final colors = Theme.of(context).colorScheme;
    Widget row(String label, String value, {bool emphasis = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: emphasis ? 20 : 14,
                color: emphasis ? colors.primary : colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('Tổng tiền đơn', money.format(balance.total)),
        row(
          purchase ? 'Đã trả thực tế' : 'Đã thu thực tế',
          money.format(balance.paid),
        ),
        if (balance.basis == 'RETURN_LEDGER' && order['refundedAmount'] is num)
          row('Đã hoàn cho khách', money.format(order['refundedAmount'])),
        if (balance.adjustment != 0) ...[
          row(
            'Điều chỉnh công nợ đầu kỳ',
            '${balance.adjustment > 0 ? '+' : ''}${money.format(balance.adjustment)}',
          ),
          Text(
            'Khoản điều chỉnh không phải tiền đã ${purchase ? 'trả' : 'thu'}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const Divider(height: 20),
        if (balance.basis == 'NOT_POSTED')
          const Text('Công nợ được ghi nhận khi xác nhận đã nhận hàng.')
        else if (balance.basis == 'NOT_EFFECTIVE')
          const Text('Khoản công nợ chưa đến ngày có hiệu lực.')
        else if (balance.basis == 'CLOSED')
          Text(balance.label)
        else
          row(
            purchase
                ? 'Còn phải trả'
                : balance.basis == 'RETURN_LEDGER'
                ? 'Phí giao hàng còn phải thu'
                : 'Còn phải thu',
            balance.remaining == null
                ? 'Cần đối chiếu'
                : money.format(balance.remaining),
            emphasis: true,
          ),
        if (balance.basis == 'ORDER' && (balance.remaining ?? 0) > 0)
          const Text(
            'Đơn chưa có khoản công nợ liên kết. Cần đối chiếu trước khi thu thêm.',
          ),
        if (balance.closedByAdjustment)
          Text(
            'Đã hết dư nợ sau điều chỉnh.',
            style: TextStyle(color: colors.primary),
          ),
        if (balance.remaining == null)
          const Text(
            'Số liệu đơn hàng và công nợ liên kết chưa khớp. Cần đối chiếu trước khi thu/trả thêm.',
          ),
      ],
    );
  }
}
