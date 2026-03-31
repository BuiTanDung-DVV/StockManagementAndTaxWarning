import 'product_form_screen.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/product_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class ProductDetailScreen extends ConsumerWidget {
  final int id;
  const ProductDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(productDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text('Sản phẩm #$id'), actions: [
        featureGuideButton(context, 'product_detail'),
        IconButton(icon: const Icon(Icons.edit), onPressed: () async {
          final asyncVal = detailAsync;
          if (asyncVal.hasValue) {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: asyncVal.value!)));
            ref.invalidate(productDetailProvider(id));
          }
        }),
      ]),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('Không tải được dữ liệu\n$e', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => ref.invalidate(productDetailProvider(id)), child: const Text('Thử lại')),
        ])),
        data: (p) {
          final name = p['name'] ?? 'Sản phẩm $id';
          final sku = p['sku'] ?? '';
          final category = p['category']?['name'] ?? p['categoryName'] ?? '';
          final unit = p['unit'] ?? '';
          final barcode = p['barcode'] ?? '';
          final costPrice = (p['costPrice'] as num?)?.toDouble() ?? 0;
          final sellingPrice = (p['sellingPrice'] as num?)?.toDouble() ?? 0;
          final wholesalePrice = (p['wholesalePrice'] as num?)?.toDouble() ?? 0;
          final taxRate = p['taxRate'] ?? p['tax'] ?? '';
          final currentStock = (p['currentStock'] ?? p['quantity'] ?? 0);
          final minStock = (p['minStock'] ?? p['minimumStock'] ?? 0);
          final stockStatus = (currentStock is num && minStock is num && currentStock <= minStock) ? 'Sắp hết' : 'Đủ hàng';
          final statusColor = stockStatus == 'Sắp hết' ? AppColors.danger : AppColors.success;

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 120, height: 120, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.inventory_2, size: 50, color: AppColors.primary))),
            const SizedBox(height: 16),
            Center(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 24),
            _Section('Thông tin chung', [
              if (sku.isNotEmpty) _InfoTile('SKU', sku),
              if (category.isNotEmpty) _InfoTile('Danh mục', category),
              if (unit.isNotEmpty) _InfoTile('Đơn vị', unit),
              if (barcode.isNotEmpty) _InfoTile('Mã vạch', barcode),
            ]),
            _Section('Giá bán', [
              _InfoTile('Giá vốn', _currFmt.format(costPrice)),
              _InfoTile('Giá bán lẻ', _currFmt.format(sellingPrice)),
              if (wholesalePrice > 0) _InfoTile('Giá sỉ', _currFmt.format(wholesalePrice)),
              if (taxRate.toString().isNotEmpty) _InfoTile('Thuế', '$taxRate%'),
            ]),
            _Section('Tồn kho', [
              _InfoTile('Tổng tồn', '$currentStock'),
              _InfoTile('Tồn tối thiểu', '$minStock'),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Trạng thái', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 13)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(stockStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor))),
              ]),
            ]),
          ]));
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title; final List<Widget> children;
  const _Section(this.title, this.children);
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)), child: Column(children: children)),
    const SizedBox(height: 16),
  ]);
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile(this.label, this.value);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 13)), Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), textAlign: TextAlign.end))]));
}
