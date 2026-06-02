import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../providers/inventory_provider.dart';
import 'stock_take_form_screen.dart';

class StockTakeScreen extends ConsumerWidget {
  const StockTakeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final stockAsync = ref.watch(stockProvider(null));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Kiểm kê Kho',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'stock_take'),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StockTakeFormScreen()),
          );
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        icon: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 20),
        label: Text(
          'Tạo Phiếu Kiểm',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: c.textMuted),
                const SizedBox(height: 12),
                Text(
                  'Không tải được dữ liệu tồn kho\n$e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(stockProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmpty(
              message: 'Chưa có dữ liệu tồn kho',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: c.divider.withValues(alpha: 0.5)),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i] as Map;
              final name = item['product']?['name'] ?? item['productName'] ?? 'Sản phẩm không tên';
              final sku = item['product']?['sku'] ?? item['sku'] ?? '';
              final qty = item['currentQuantity'] ?? item['quantity'] ?? 0;
              final minStock = item['product']?['minStock'] ?? item['minStock'] ?? 0;
              final isLow = (qty is num && minStock is num && qty <= minStock);

              return Container(
                margin: const EdgeInsets.only(bottom: 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isLow ? AppColors.danger : AppColors.success)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: isLow ? AppColors.danger : AppColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: c.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sku.toString().isNotEmpty ? 'SKU: $sku' : 'Không có SKU',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: c.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$qty',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: isLow ? AppColors.danger : AppColors.success,
                          ),
                        ),
                        if (isLow)
                          Text(
                            'Min: $minStock',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.danger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
