import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class StockTakeScreen extends StatelessWidget {
  const StockTakeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Kiểm kê Kho'), actions: [IconButton(icon: Icon(Icons.add), onPressed: () {})]),
    body: ListView.builder(padding: EdgeInsets.all(16), itemCount: 5, itemBuilder: (_, i) => Container(
      margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('KK-${2026030 + i}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(
            color: (i < 2 ? AppColors.success : AppColors.warning).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(i < 2 ? 'Hoàn thành' : 'Đang kiểm', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: i < 2 ? AppColors.success : AppColors.warning))),
        ]),
        SizedBox(height: 6),
        Text('Ngày: 0${i + 5}/03/2026 • ${20 + i * 5} SP', style: TextStyle(fontSize: 12, color: AppThemeColors.of(context).textSecondary)),
        if (i > 2) Text('Chênh lệch: ${i - 2} SP', style: const TextStyle(fontSize: 12, color: AppColors.danger)),
      ]),
    )),
  );
}
