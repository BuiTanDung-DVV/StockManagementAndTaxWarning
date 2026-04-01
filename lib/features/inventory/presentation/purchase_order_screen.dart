import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import 'purchase_order_form_screen.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class PurchaseOrderScreen extends ConsumerWidget {
  const PurchaseOrderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final poAsync = ref.watch(purchaseOrdersProvider(1));

    return Scaffold(
      appBar: AppBar(title: const Text('Nhập hàng / Đơn mua'), actions: [
        featureGuideButton(context, 'purchase_order'),
        IconButton(
          icon: const Icon(Icons.add), 
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrderFormScreen()));
          },
        ),
      ]),
      body: poAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('Không tải được dữ liệu\n$e', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => ref.invalidate(purchaseOrdersProvider), child: const Text('Thử lại')),
        ])),
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          if (items.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.move_to_inbox_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Chưa có đơn mua hàng', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ]));
          }
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 450,
              mainAxisExtent: 85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 0,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final po = items[i] as Map;
              final code = po['orderCode'] ?? po['code'] ?? 'PO-${po['id'] ?? i}';
              final supplierName = po['supplier']?['name'] ?? po['supplierName'] ?? '';
              final totalAmount = (po['totalAmount'] as num?)?.toDouble() ?? 0;
              final createdAt = po['createdAt']?.toString().split('T').first ?? '';
              final invoiceNumber = po['invoiceNumber'] ?? '';
              final status = po['status'] ?? '';

              Color statusColor;
              String statusLabel;
              switch (status) {
                case 'COMPLETED': statusColor = AppColors.success; statusLabel = 'Hoàn thành'; break;
                case 'CANCELLED': statusColor = AppColors.danger; statusLabel = 'Đã hủy'; break;
                case 'PENDING': statusColor = AppColors.warning; statusLabel = 'Chờ xử lý'; break;
                default: statusColor = AppColors.info; statusLabel = status.isNotEmpty ? status : 'N/A';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.move_to_inbox, color: AppColors.info, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('$code', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(statusLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor))),
                    ]),
                    if (supplierName.isNotEmpty) Text('NCC: $supplierName', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    Text('${createdAt.isNotEmpty ? createdAt : ''}${invoiceNumber.isNotEmpty ? ' • HĐ: $invoiceNumber' : ''}', style: TextStyle(fontSize: 11, color: c.textMuted)),
                  ])),
                  Text(_currFmt.format(totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
