import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../settings/providers/shop_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../inventory/providers/purchase_order_detail_provider.dart';
import '../../dashboard/providers/dashboard_action_provider.dart';
import '../providers/supplier_provider.dart';
import 'supplier_payment_dialog.dart';
import 'supplier_payment_recovery_dialog.dart';

class SupplierPayablesSection extends ConsumerWidget {
  final int supplierId;
  final String supplierName;
  const SupplierPayablesSection({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final canPay = ref.watch(shopProvider).hasPermission('finance', 'edit');
    return AppCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              const Text(
                'Khoản còn phải trả',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (canPay)
                TextButton(
                  onPressed: () async {
                    await showDialog<bool>(
                      context: context,
                      builder: (_) => SupplierPaymentRecoveryDialog(
                        supplierId: supplierId,
                        supplierName: supplierName,
                      ),
                    );
                    if (context.mounted) {
                      _refreshSupplierPaymentViews(ref, supplierId);
                    }
                  },
                  child: const Text('Kiểm tra trả nợ'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ref
              .watch(supplierPayablesProvider(supplierId))
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Column(
                  children: [
                    const Text('Chưa tải được công nợ mới nhất.'),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(supplierPayablesProvider(supplierId)),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
                data: (raw) {
                  if (raw.any(
                    (item) =>
                        item is! Map ||
                        item['id'] is! int ||
                        item['supplierId'] != supplierId ||
                        num.tryParse('${item['remaining']}') == null,
                  )) {
                    return const Text(
                      'Dữ liệu khoản phải trả chưa đầy đủ. Hãy tải lại trước khi ghi nhận.',
                    );
                  }
                  final rows = raw
                      .map((item) => Map<String, dynamic>.from(item as Map))
                      .where(
                        (item) =>
                            (num.tryParse('${item['remaining']}') ?? 0) > 0 &&
                            item['openingEffective'] != false &&
                            item['status'] != 'CANCELLED',
                      )
                      .toList();
                  if (rows.isEmpty) {
                    return const Text('Không có khoản còn phải trả.');
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final item = rows[index];
                        final adjustment =
                            num.tryParse(
                              '${item['openingAdjustmentAmount']}',
                            ) ??
                            0;
                        final due = DateTime.tryParse('${item['dueDate']}');
                        final today = DateUtils.dateOnly(DateTime.now());
                        final overdue =
                            due != null &&
                            DateUtils.dateOnly(due).isBefore(today);
                        final info = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Khoản nợ #${item['id']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              due == null
                                  ? 'Chưa có hạn thanh toán'
                                  : '${overdue ? 'Quá hạn' : 'Đến hạn'} ${DateFormat('dd/MM/yyyy').format(due)}',
                              style: TextStyle(
                                color: overdue
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Đã trả: ${money.format(num.tryParse('${item['paidAmount']}') ?? 0)}',
                            ),
                            if (adjustment != 0)
                              Text(
                                'Điều chỉnh đầu kỳ: ${money.format(adjustment)} · Không phải tiền đã trả.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        );
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 600;
                            final remaining = Text(
                              money.format(num.parse('${item['remaining']}')),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                            final action = Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Còn phải trả',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                remaining,
                                if (canPay)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final result = await showDialog<bool>(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (_) => SupplierPaymentDialog(
                                            payable: item,
                                            supplierName: supplierName,
                                          ),
                                        );
                                        if (result != true ||
                                            !context.mounted) {
                                          return;
                                        }
                                        _refreshSupplierPaymentViews(
                                          ref,
                                          supplierId,
                                        );
                                      },
                                      child: const Text('Ghi nhận đã trả'),
                                    ),
                                  ),
                              ],
                            );
                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  info,
                                  const SizedBox(height: 8),
                                  action,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: info),
                                const SizedBox(width: 20),
                                action,
                              ],
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}

void _refreshSupplierPaymentViews(WidgetRef ref, int supplierId) {
  ref.invalidate(supplierPayablesProvider(supplierId));
  ref.invalidate(supplierDetailProvider(supplierId));
  ref.invalidate(supplierListProvider);
  ref.invalidate(supplierOptionsProvider);
  ref.invalidate(supplierPayablesAgingProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(cashSummaryProvider);
  ref.invalidate(expensesByCategoryProvider);
  ref.invalidate(cashflowProjectionProvider);
  ref.invalidate(dailyClosingProvider);
  ref.invalidate(dashboardActionProvider);
  ref.invalidate(purchaseOrdersProvider);
  ref.invalidate(purchaseOrderQueryProvider);
  ref.invalidate(purchaseOrderDetailProvider);
}
