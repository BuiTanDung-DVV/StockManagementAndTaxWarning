import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final stockAsync = ref.watch(stockProvider(null));
    final lowAsync = ref.watch(lowStockProvider);
    final expiringAsync = ref.watch(expiringProductsProvider);
    final slowAsync = ref.watch(slowMovingProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Quản lý Kho'), actions: [featureGuideButton(context, 'inventory')]),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(stockProvider);
          ref.invalidate(lowStockProvider);
          ref.invalidate(expiringProductsProvider);
          ref.invalidate(slowMovingProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Stats
            Row(children: [
              Expanded(child: stockAsync.when(
                data: (items) => _StatCard('Tổng SP', '${items.length}', Icons.inventory_2, AppColors.primary),
                loading: () => _StatCard('Tổng SP', '...', Icons.inventory_2, AppColors.primary),
                error: (_, _) => _StatCard('Tổng SP', '?', Icons.inventory_2, AppColors.danger),
              )),
              SizedBox(width: 12),
              Expanded(child: lowAsync.when(
                data: (items) => _StatCard('Dưới DMức', '${items.length}', Icons.warning, items.isEmpty ? AppColors.success : AppColors.warning),
                loading: () => _StatCard('Dưới DMức', '...', Icons.warning, AppColors.warning),
                error: (_, _) => _StatCard('Dưới DMức', '?', Icons.warning, AppColors.danger),
              )),
            ]),
            SizedBox(height: 12),
            Row(children: [
              Expanded(child: expiringAsync.when(
                data: (items) => _StatCard('Sắp HSD', '${items.length}', Icons.schedule, items.isEmpty ? AppColors.success : AppColors.danger),
                loading: () => _StatCard('Sắp HSD', '...', Icons.schedule, AppColors.warning),
                error: (_, _) => _StatCard('Sắp HSD', '?', Icons.schedule, AppColors.danger),
              )),
              const SizedBox(width: 12),
              const Expanded(child: _StatCard('Kho', '—', Icons.warehouse, AppColors.info)),
            ]),
            const SizedBox(height: 24),
            Text('Thao tác nhanh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _ActionTile('Kiểm kê kho', Icons.fact_check, () => context.push('/stock-take')),
            _ActionTile('Nhập hàng', Icons.move_to_inbox, () => context.push('/purchase-orders')),
            _ActionTile('Báo cáo XNT', Icons.analytics, () => context.push('/xnt-report')),
            const SizedBox(height: 24),
            // Low stock list
            lowAsync.when(
              data: (items) {
                if (items.isEmpty) return SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('⚠ Dưới định mức tối thiểu (${items.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.danger)),
                  SizedBox(height: 8),
                  ...items.take(5).map((item) => Container(
                    margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Expanded(child: Text(item['product']?['name'] ?? item['productName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('Tồn: ${item['currentQuantity'] ?? item['quantity'] ?? 0}', style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.bold)),
                    ]),
                  )),
                ]);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            // Slow moving list
            slowAsync.when(
              data: (items) {
                if (items.isEmpty) return SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 16),
                  Text('⚠ Chậm luân chuyển (Đọng vốn) (${items.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.warning)),
                  SizedBox(height: 8),
                  ...items.take(5).map((item) => Container(
                    margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
                    child: Row(children: [
                      Expanded(child: Text(item['product']?['name'] ?? item['productName'] ?? '', style: TextStyle(fontWeight: FontWeight.w600))),
                      Text('Tồn vướng: ${item['currentQuantity'] ?? item['quantity'] ?? 0}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ]),
                  )),
                ]);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value; final IconData icon; final Color color;
  const _StatCard(this.title, this.value, this.icon, this.color);
  @override Widget build(BuildContext context) => Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 20, color: color), const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(title, style: TextStyle(fontSize: 11, color: AppThemeColors.of(context).textSecondary)),
    ]));
}

class _ActionTile extends StatelessWidget {
  final String title; final IconData icon; final VoidCallback onTap;
  const _ActionTile(this.title, this.icon, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600))),
        Icon(Icons.chevron_right, color: AppThemeColors.of(context).textMuted),
      ])));
}
