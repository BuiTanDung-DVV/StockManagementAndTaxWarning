import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_icon.dart';
import '../../customers/providers/customer_provider.dart';
import '../../settings/providers/shop_provider.dart';

/// An explanation before recording debt. The server rechecks the actual limit.
class CustomerCreditPreview extends ConsumerWidget {
  final int customerId;
  final double additionalDebt;
  const CustomerCreditPreview({
    super.key,
    required this.customerId,
    required this.additionalDebt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProvider);
    if (shop.isAllShops || !shop.hasPermission('customers', 'view')) {
      return const Text('Hạn mức công nợ sẽ được kiểm tra khi ghi đơn.');
    }
    final data = ref.watch(customerDetailProvider(customerId));
    return data.when(
      skipLoadingOnRefresh: false,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Đang kiểm tra công nợ khách hàng…'),
      ),
      error: (_, _) => _unavailable(ref),
      data: (customer) {
        final balance = num.tryParse('${customer['balance']}');
        final limit = num.tryParse('${customer['creditLimit']}');
        if (customer['id'] != customerId ||
            customer['shopId'] != shop.currentShopId ||
            customer['balanceBasis'] != 'CURRENT' ||
            balance == null ||
            limit == null ||
            !balance.isFinite ||
            !limit.isFinite ||
            balance < 0 ||
            limit < 0 ||
            !additionalDebt.isFinite ||
            additionalDebt < 0) {
          return _unavailable(ref);
        }
        return CustomerCreditInfo(
          balance: balance.toDouble(),
          limit: limit.toDouble(),
          additionalDebt: additionalDebt,
          onRefresh: () => ref.invalidate(customerDetailProvider(customerId)),
        );
      },
    );
  }

  Widget _unavailable(WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Chưa lấy được công nợ hiện tại. Hệ thống vẫn kiểm tra hạn mức khi ghi đơn.',
      ),
      TextButton(
        onPressed: () => ref.invalidate(customerDetailProvider(customerId)),
        child: const Text('Tải lại công nợ'),
      ),
    ],
  );
}

class CustomerCreditInfo extends StatelessWidget {
  final double balance, limit, additionalDebt;
  final VoidCallback onRefresh;
  const CustomerCreditInfo({
    super.key,
    required this.balance,
    required this.limit,
    required this.additionalDebt,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final projected = balance + additionalDebt;
    final excess = limit > 0 ? projected - limit : 0.0;
    final warning = excess > 0.005;
    final color = warning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    Widget line(String label, double amount, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              money.format(amount),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nếu ghi nợ toàn bộ đơn này',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  tooltip: 'Tải lại công nợ',
                  icon: const AppIcon(Icons.refresh, size: 18),
                ),
              ],
            ),
            line('Công nợ đang có', balance),
            line('Nợ thêm từ đơn này', additionalDebt),
            line('Công nợ sau ghi đơn', projected, strong: true),
            const Divider(),
            if (limit > 0)
              line('Hạn mức đã đặt', limit)
            else
              const Text('Chưa đặt hạn mức công nợ.'),
            if (limit > 0)
              Text(
                warning
                    ? 'Vượt hạn mức ${money.format(excess)}. Thu nợ cũ hoặc ghi nhận thu đủ tiền trước khi thêm công nợ.'
                    : 'Trong hạn mức; còn ${money.format((limit - projected).clamp(0, double.infinity))}.',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 8),
            Text(
              'Thông tin tham khảo. Hệ thống kiểm tra lại khi ghi đơn; chọn thu đủ tiền thì không phát sinh nợ mới.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
