import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/supplier_provider.dart';

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final listAsync = ref.watch(supplierListProvider((page: 1, search: null)));
    return Scaffold(
      appBar: AppBar(title: Text('Nhà cung cấp'), actions: [featureGuideButton(context, 'supplier_list'), IconButton(icon: Icon(Icons.add), onPressed: () {})]),
      body: listAsync.when(
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          if (items.isEmpty) return Center(child: Text('Chưa có NCC', style: TextStyle(color: c.textSecondary)));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(supplierListProvider),
            child: ListView.builder(padding: EdgeInsets.all(16), itemCount: items.length, itemBuilder: (_, i) {
              final s = items[i];
              return GestureDetector(
                onTap: () => context.go('/suppliers/${s['id']}'),
                child: Container(margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.business, color: AppColors.info)),
                    SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('MST: ${s['taxCode'] ?? 'N/A'}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      if (s['paymentTermDays'] != null) Text('Thanh toán: ${s['paymentTermDays']} ngày', style: TextStyle(fontSize: 11, color: c.textMuted)),
                    ])),
                    Icon(Icons.chevron_right, color: c.textMuted),
                  ]),
                ),
              );
            }),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: AppColors.danger))),
      ),
    );
  }
}
