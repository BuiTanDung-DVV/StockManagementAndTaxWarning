import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/sales_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});
  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  int _page = 1;
  String? _status;
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final listAsync = ref.watch(salesListProvider((page: _page, status: _status)));

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(padding: EdgeInsets.all(16), child: Row(children: [
            const Expanded(child: Text('Đơn hàng', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            featureGuideButton(context, 'sales_list'),
            IconButton(icon: Icon(_searching ? Icons.close : Icons.search, color: c.textSecondary), onPressed: () => setState(() { _searching = !_searching; if (!_searching) _searchCtrl.clear(); })),
          ])),
          if (_searching)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: TextField(
              controller: _searchCtrl, autofocus: true,
              decoration: InputDecoration(hintText: 'Tìm đơn hàng, khách hàng...', prefixIcon: Icon(Icons.search, color: c.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: c.card),
            )),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [null, 'PENDING', 'COMPLETED', 'CANCELLED'].map((s) {
                final label = s == null ? 'Tất cả' : s == 'PENDING' ? 'Chờ xử lý' : s == 'COMPLETED' ? 'Hoàn thành' : 'Đã hủy';
                final selected = _status == s;
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() { _status = s; _page = 1; }),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(color: selected ? AppColors.primary : c.textSecondary, fontSize: 12),
                    side: BorderSide(color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.1)),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 12),
          Expanded(
            child: listAsync.when(
              data: (data) {
                final items = (data['items'] as List?) ?? [];
                if (items.isEmpty) {
                  return AppEmpty(message: 'Chưa có đơn hàng nào', subtitle: 'Tạo đơn hàng đầu tiên từ màn hình POS');
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(salesListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final order = items[i];
                      final orderStatus = order['status'] ?? 'PENDING';
                      final color = orderStatus == 'COMPLETED' ? AppColors.success : orderStatus == 'PENDING' ? AppColors.warning : AppColors.danger;
                      final statusLabel = orderStatus == 'COMPLETED' ? 'Hoàn thành' : orderStatus == 'PENDING' ? 'Chờ' : 'Hủy';
                      final total = (order['totalAmount'] ?? 0).toDouble();
                      final customerName = order['customer']?['name'] ?? 'Khách lẻ';

                      return GestureDetector(
                        onTap: () => context.push('/sales/${order['id']}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                            ),
                            SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('DH-${order['id']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              SizedBox(height: 2),
                              Text(customerName, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(_currFmt.format(total), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                              ),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const ShimmerList(),
              error: (e, _) => AppError(message: 'Lỗi: $e', onRetry: () => ref.invalidate(salesListProvider)),
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => context.push('/pos'), child: const Icon(Icons.add)),
    );
  }
}
