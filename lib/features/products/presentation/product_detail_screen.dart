import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/product_provider.dart';
import 'product_form_screen.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class ProductDetailScreen extends ConsumerWidget {
  final int id;
  const ProductDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final detailAsync = ref.watch(productDetailProvider(id));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Chi Tiết Sản Phẩm',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'product_detail'),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              if (detailAsync.hasValue) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProductFormScreen(product: detailAsync.value!)),
                );
                ref.invalidate(productDetailProvider(id));
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: detailAsync.when(
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
                  'Không tải được dữ liệu sản phẩm\n$e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(productDetailProvider(id)),
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
        data: (p) {
          final name = p['name'] ?? 'Sản phẩm không tên';
          final sku = p['sku'] ?? '';
          final category = p['category']?['name'] ?? p['categoryName'] ?? '';
          final unit = p['unit'] ?? '';
          final barcode = p['barcode'] ?? '';
          final costPrice = _asDouble(p['costPrice']);
          final sellingPrice = _asDouble(p['sellingPrice'] ?? p['sellPrice']);
          final wholesalePrice = _asDouble(p['wholesalePrice']);
          final taxRate = p['taxRate'] ?? p['tax'] ?? '';
          final currentStock = (p['currentStock'] ?? p['quantity'] ?? 0);
          final minStock = (p['minStock'] ?? p['minimumStock'] ?? 0);
          final stockStatus = (currentStock is num && minStock is num && currentStock <= minStock) ? 'Sắp hết hàng' : 'Đang an toàn';
          final statusColor = stockStatus == 'Sắp hết hàng' ? AppColors.danger : AppColors.success;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium visual card for product icon & details
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15), width: 1.5),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Info Section 1: General Info
                _Section('Thông tin chung', [
                  if (sku.isNotEmpty) _InfoTile('Mã SKU', sku),
                  if (category.isNotEmpty) _InfoTile('Danh mục phân loại', category),
                  if (unit.isNotEmpty) _InfoTile('Đơn vị tính', unit),
                  if (barcode.isNotEmpty) _InfoTile('Mã vạch barcode', barcode),
                ]),

                // Info Section 2: Pricing details
                _Section('Chính sách giá bán', [
                  _InfoTile('Giá vốn nhập', _currFmt.format(costPrice)),
                  _InfoTile('Giá bán lẻ', _currFmt.format(sellingPrice)),
                  if (wholesalePrice > 0) _InfoTile('Giá bán sỉ', _currFmt.format(wholesalePrice)),
                  if (taxRate.toString().isNotEmpty) _InfoTile('Thuế suất áp dụng', '$taxRate%'),
                ]),

                // Info Section 3: Stock parameters
                _Section('Thông số tồn kho', [
                  _InfoTile('Tổng số tồn kho hiện tại', '$currentStock'),
                  _InfoTile('Ngưỡng tối thiểu (Min)', '$minStock'),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trạng thái kho hàng',
                        style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          stockStatus,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.divider.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: children,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: c.textPrimary,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
