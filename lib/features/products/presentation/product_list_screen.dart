import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/product_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final listAsync = ref.watch(productListProvider((page: 1, search: null)));
    return Scaffold(
      appBar: AppBar(title: Text('Sản phẩm'), actions: [featureGuideButton(context, 'product_list'), IconButton(icon: Icon(Icons.add), onPressed: () {})]),
      body: Column(children: [
        Padding(padding: EdgeInsets.all(16), child: TextField(decoration: InputDecoration(hintText: 'Tìm sản phẩm...', prefixIcon: Icon(Icons.search, color: c.textMuted)))),
        Expanded(child: listAsync.when(
          data: (data) {
            final items = (data['items'] as List?) ?? [];
            if (items.isEmpty) return Center(child: Text('Chưa có sản phẩm', style: TextStyle(color: c.textSecondary)));
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(productListProvider),
              child: ListView.builder(padding: EdgeInsets.symmetric(horizontal: 16), itemCount: items.length, itemBuilder: (_, i) {
                final p = items[i];
                final price = (p['sellingPrice'] ?? p['retailPrice'] ?? 0).toDouble();
                final stock = p['currentStock'] ?? p['stock'] ?? 0;
                return Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Container(width: 55, height: 55, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.inventory_2, color: AppColors.primary)),
                    SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('SKU: ${p['sku'] ?? 'N/A'}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      Text('Tồn: $stock', style: TextStyle(fontSize: 11, color: stock < 10 ? AppColors.danger : c.textSecondary)),
                    ])),
                    Text(_currFmt.format(price), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ]),
                );
              }),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: AppColors.danger))),
        )),
      ]),
    );
  }
}
