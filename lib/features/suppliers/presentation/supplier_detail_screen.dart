import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SupplierDetailScreen extends StatelessWidget {
  final int id;
  const SupplierDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('NCC #$id'), actions: [featureGuideButton(context, 'supplier_detail')]),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      Container(width: 70, height: 70, decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.business, size: 36, color: AppColors.info)),
      const SizedBox(height: 12),
      Text('Nhà cung cấp $id', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      _Card([_R('MST', '03012345${id}78'), _R('Liên hệ', 'Nguyễn Văn $id'), _R('SĐT', '028-3900-100$id'), _R('Email', 'ncc$id@supplier.vn'), _R('Địa chỉ', '$id Lý Thường Kiệt, Q.Tân Bình'), _R('Ngân hàng', 'Vietcombank'), _R('STK', '007100${id}5678'), _R('Kỳ TT', '${id * 15} ngày')]),
      const SizedBox(height: 12),
      _Card([_R('Tổng nhập', '₫${id * 10}M'), _R('Công nợ NCC', '₫${id * 2}M'), _R('Đơn nhập cuối', '05/03/2026')]),
    ])),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card(this.children);
  @override Widget build(BuildContext context) => Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)), child: Column(children: children));
}

class _R extends StatelessWidget {
  final String l, v;
  const _R(this.l, this.v);
  @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 13)), Flexible(child: Text(v, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13), textAlign: TextAlign.end))]));
}
