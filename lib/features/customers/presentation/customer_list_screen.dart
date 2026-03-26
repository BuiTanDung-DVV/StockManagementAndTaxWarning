import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/customer_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final listAsync = ref.watch(customerListProvider((page: 1, search: null)));
    return Scaffold(
      appBar: AppBar(title: Text('Khách hàng'), actions: [IconButton(icon: Icon(Icons.person_add), onPressed: () {})]),
      body: listAsync.when(
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          if (items.isEmpty) return Center(child: Text('Chưa có khách hàng', style: TextStyle(color: c.textSecondary)));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(customerListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: items.length,
              itemBuilder: (_, i) {
                final c = items[i];
                final debt = (c['totalDebt'] ?? 0).toDouble();
                return GestureDetector(
                  onTap: () => context.go('/customers/${c['id']}'),
                  child: Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      CircleAvatar(radius: 22, backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text((c['name'] ?? 'K')[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                      SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(c['phone'] ?? '', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ])),
                      if (debt > 0) Text(_currFmt.format(debt), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: debt > 5000000 ? AppColors.danger : c.textPrimary)),
                    ]),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: AppColors.danger))),
      ),
    );
  }
}
