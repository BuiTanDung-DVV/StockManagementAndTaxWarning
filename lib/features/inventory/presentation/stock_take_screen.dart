import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';

import 'stock_take_form_screen.dart';

class StockTakeScreen extends ConsumerWidget {
  const StockTakeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final stockAsync = ref.watch(stockProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm kê Kho'), actions: [
        featureGuideButton(context, 'stock_take'),
        IconButton(icon: const Icon(Icons.add), onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const StockTakeFormScreen()));
        }),
      ]),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('Không tải được dữ liệu\n$e', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => ref.invalidate(stockProvider), child: const Text('Thử lại')),
        ])),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.inventory_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Chưa có dữ liệu tồn kho', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i] as Map;
              final name = item['product']?['name'] ?? item['productName'] ?? 'SP';
              final sku = item['product']?['sku'] ?? item['sku'] ?? '';
              final qty = item['currentQuantity'] ?? item['quantity'] ?? 0;
              final minStock = item['product']?['minStock'] ?? item['minStock'] ?? 0;
              final isLow = (qty is num && minStock is num && qty <= minStock);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isLow ? AppColors.danger : AppColors.success).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.inventory_2, color: isLow ? AppColors.danger : AppColors.success, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (sku.toString().isNotEmpty) Text('SKU: $sku', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLow ? AppColors.danger : AppColors.success)),
                    if (isLow) Text('Min: $minStock', style: const TextStyle(fontSize: 10, color: AppColors.danger)),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
