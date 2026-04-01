import 'customer_form_screen.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
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
    final tc = AppThemeColors.of(context);
    final listAsync = ref.watch(customerListProvider((page: 1, search: null)));
    return Scaffold(
      appBar: AppBar(title: Text('Khách hàng'), actions: [featureGuideButton(context, 'customer_list'), IconButton(icon: Icon(Icons.person_add), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerFormScreen())))]),
      body: listAsync.when(
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          if (items.isEmpty) return AppEmpty(message: 'Chưa có khách hàng', subtitle: 'Hãy thêm khách hàng đầu tiên');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(customerListProvider),
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 450,
                mainAxisExtent: 85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 0,
              ),
              itemBuilder: (_, i) {
                final cust = items[i];
                final debt = (cust['totalDebt'] ?? 0).toDouble();
                return GestureDetector(
                  onTap: () => context.push('/customers/${cust['id']}'),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(color: tc.card, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      CircleAvatar(radius: 22, backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text((cust['name'] ?? 'K')[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                      SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cust['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(cust['phone'] ?? '', style: TextStyle(fontSize: 12, color: tc.textSecondary)),
                      ])),
                      if (debt > 0) Text(_currFmt.format(debt), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: debt > 5000000 ? AppColors.danger : tc.textPrimary)),
                    ]),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const ShimmerList(),
        error: (e, _) => AppError(message: 'Lỗi: $e', onRetry: () => ref.invalidate(customerListProvider)),
      ),
    );
  }
}
