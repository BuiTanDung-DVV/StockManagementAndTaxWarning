import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/guides/feature_guide_sheet.dart';
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
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Quản lý Kho',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'inventory'),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(stockProvider);
          ref.invalidate(lowStockProvider);
          ref.invalidate(expiringProductsProvider);
          ref.invalidate(slowMovingProvider);
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Beautiful Stats Cards (Bento style)
              Row(
                children: [
                  Expanded(
                    child: stockAsync.when(
                      data: (items) => _StatCard(
                        'Tổng SP',
                        '${items.length}',
                        Icons.inventory_2_rounded,
                        AppColors.primary,
                      ),
                      loading: () => _StatCard(
                        'Tổng SP',
                        '...',
                        Icons.inventory_2_rounded,
                        AppColors.primary,
                      ),
                      error: (e, s) => _StatCard(
                        'Tổng SP',
                        '?',
                        Icons.inventory_2_rounded,
                        AppColors.danger,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: lowAsync.when(
                      data: (items) => _StatCard(
                        'Dưới DMức',
                        '${items.length}',
                        Icons.warning_amber_rounded,
                        items.isEmpty ? AppColors.success : AppColors.warning,
                      ),
                      loading: () => _StatCard(
                        'Dưới DMức',
                        '...',
                        Icons.warning_amber_rounded,
                        AppColors.warning,
                      ),
                      error: (e, s) => _StatCard(
                        'Dưới DMức',
                        '?',
                        Icons.warning_amber_rounded,
                        AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: expiringAsync.when(
                      data: (items) => _StatCard(
                        'Sắp HSD',
                        '${items.length}',
                        Icons.schedule_rounded,
                        items.isEmpty ? AppColors.success : AppColors.danger,
                      ),
                      loading: () => _StatCard(
                        'Sắp HSD',
                        '...',
                        Icons.schedule_rounded,
                        AppColors.warning,
                      ),
                      error: (e, s) => _StatCard(
                        'Sắp HSD',
                        '?',
                        Icons.schedule_rounded,
                        AppColors.danger,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: _StatCard(
                      'Kho hàng',
                      '1',
                      Icons.warehouse_rounded,
                      AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Quick Actions section
              Text(
                'Thao tác nhanh',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                'Kiểm kê kho',
                Icons.fact_check_rounded,
                () => context.push('/stock-take'),
              ),
              _ActionTile(
                'Nhập hàng (Đơn mua)',
                Icons.move_to_inbox_rounded,
                () => context.push('/purchase-orders'),
              ),
              _ActionTile(
                'Báo cáo xuất nhập tồn',
                Icons.analytics_rounded,
                () => context.push('/xnt-report'),
              ),
              
              // Low stock dynamic alerts list
              lowAsync.when(
                data: (items) {
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.danger,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dưới định mức tối thiểu (${items.length})',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...items.take(5).map((item) {
                        final prodName = item['product']?['name'] ?? item['productName'] ?? 'Sản phẩm không tên';
                        final qty = item['currentQuantity'] ?? item['quantity'] ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.divider.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  prodName,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Tồn: $qty',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
              ),
              
              // Slow moving list
              slowAsync.when(
                data: (items) {
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_off_outlined,
                            color: AppColors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Chậm luân chuyển (Đọng vốn) (${items.length})',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...items.take(5).map((item) {
                        final prodName = item['product']?['name'] ?? item['productName'] ?? 'Sản phẩm không tên';
                        final qty = item['currentQuantity'] ?? item['quantity'] ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  prodName,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Tồn vướng: $qty',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 22, color: color),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionTile(this.title, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: c.divider.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: c.textMuted,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
