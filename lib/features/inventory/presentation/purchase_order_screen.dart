import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PurchaseOrderScreen extends StatelessWidget {
  const PurchaseOrderScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Nhập hàng / Đơn mua'), actions: [IconButton(icon: Icon(Icons.add), onPressed: () {})]),
    body: ListView.builder(padding: EdgeInsets.all(16), itemCount: 8, itemBuilder: (_, i) => Container(
      margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.move_to_inbox, color: AppColors.info, size: 20)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PO-${2000 + i}', style: TextStyle(fontWeight: FontWeight.w600)),
          Text('NCC: Nhà cung cấp ${(i % 4) + 1}', style: TextStyle(fontSize: 11, color: AppThemeColors.of(context).textSecondary)),
          Text('Ngày: 0${i + 1}/03/2026 • HĐ: ${i < 5 ? 'HD-00${i}5' : 'Chưa có'}', style: TextStyle(fontSize: 11, color: AppThemeColors.of(context).textMuted)),
        ])),
        Text('₫${(i + 1) * 3}M', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
      ]),
    )),
  );
}
