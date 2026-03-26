import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ProductDetailScreen extends StatelessWidget {
  final int id;
  const ProductDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Sản phẩm #$id'), actions: [IconButton(icon: const Icon(Icons.edit), onPressed: () {})]),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 120, height: 120, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.inventory_2, size: 50, color: AppColors.primary))),
      const SizedBox(height: 16),
      Center(child: Text('Sản phẩm $id', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      const SizedBox(height: 24),
      _Section('Thông tin chung', [_InfoTile('SKU', 'SP-${1000 + id}'), _InfoTile('Danh mục', 'Thực phẩm'), _InfoTile('Đơn vị', 'Cái'), _InfoTile('Mã vạch', '8934567890$id')]),
      _Section('Giá bán', [_InfoTile('Giá vốn', '₫${id * 50}K'), _InfoTile('Giá bán lẻ', '₫${id * 100}K'), _InfoTile('Giá sỉ', '₫${id * 80}K'), _InfoTile('Thuế', '10%')]),
      _Section('Tồn kho', [_InfoTile('Tổng tồn', '${50 - id * 3}'), _InfoTile('Tồn tối thiểu', '10'), _InfoTile('Trạng thái', id * 3 > 40 ? 'Sắp hết' : 'Đủ hàng')]),
    ])),
  );
}

class _Section extends StatelessWidget {
  final String title; final List<Widget> children;
  const _Section(this.title, this.children);
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), SizedBox(height: 8),
    Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)), child: Column(children: children)),
    const SizedBox(height: 16),
  ]);
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile(this.label, this.value);
  @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 13)), Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13))]));
}
