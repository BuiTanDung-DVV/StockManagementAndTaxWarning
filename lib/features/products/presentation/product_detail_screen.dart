import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/cloudinary_image.dart';
import '../providers/product_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../../core/utils/type_parser.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import 'product_form_screen.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const ProductDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _movementPage = 1;
  int get id => widget.id;

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final detailAsync = ref.watch(productDetailProvider(id));
    final compactLayout = MediaQuery.sizeOf(context).width < 720;
    Future<void> openEdit() async {
      final product = detailAsync.value;
      if (product == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
      );
      ref.invalidate(productDetailProvider(id));
    }

    final movementsAsync = ref.watch(
      inventoryMovementsProvider((productId: id, page: _movementPage)),
    );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Chi Tiết Sản Phẩm',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'product_detail'),
          if (compactLayout && detailAsync.hasValue)
            AppPrimaryHeaderAction(
              label: 'Chỉnh sửa',
              assetPath: AppAssets.edit,
              heroTag: 'product-edit-compact',
              onPressed: openEdit,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (p) {
          final name = p['name'] ?? 'Sản phẩm không tên';
          final imageUrl = p['imageUrl']?.toString().trim() ?? '';
          final sku = p['sku'] ?? '';
          final category = p['category']?['name'] ?? p['categoryName'] ?? '';
          final unit = p['unit'] ?? '';
          final barcode = p['barcode'] ?? '';
          final rawDesc = p['description']?.toString().trim() ?? '';
          final description = rawDesc.isEmpty ? 'Không có mô tả' : rawDesc;
          final descIsMissing = rawDesc.isEmpty;
          final costPrice = TypeParser.asDouble(p['costPrice']);
          final sellingPrice = TypeParser.asDouble(
            p['sellingPrice'] ?? p['sellPrice'],
          );
          final wholesalePrice = TypeParser.asDouble(p['wholesalePrice']);
          final taxRate = p['taxRate'] ?? p['tax'] ?? '';
          final currentStock = (p['currentStock'] ?? p['quantity'] ?? 0);
          final minStock = (p['minStock'] ?? p['minimumStock'] ?? 0);
          final stockStatus =
              (currentStock is num &&
                  minStock is num &&
                  currentStock <= minStock)
              ? 'Sắp hết hàng'
              : 'Đang an toàn';
          final statusColor = stockStatus == 'Sắp hết hàng'
              ? AppColors.danger
              : AppColors.success;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium visual card for product icon & details
                Center(
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: c.divider),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: imageUrl.isEmpty
                          ? _ProductImageFallback(
                              color: theme.colorScheme.primary,
                            )
                          : CachedNetworkImage(
                              imageUrl: optimizedCloudinaryImageUrl(
                                imageUrl,
                                width: 480,
                                height: 480,
                                crop: 'fill',
                              ),
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  Container(color: c.surface),
                              errorWidget: (_, _, _) => _ProductImageFallback(
                                color: theme.colorScheme.primary,
                              ),
                            ),
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
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (p['tags'] != null) ...[
                  const SizedBox(height: 12),
                  Center(child: _buildTagsRow(p['tags'], c, theme)),
                ],
                if (!descIsMissing) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mô tả sản phẩm',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: c.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Info Section 1: General Info
                _Section('Thông tin chung', [
                  if (sku.isNotEmpty) _InfoTile('Mã SKU', sku),
                  if (category.isNotEmpty)
                    _InfoTile('Danh mục phân loại', category),
                  if (unit.isNotEmpty) _InfoTile('Đơn vị tính', unit),
                  if (barcode.isNotEmpty) _InfoTile('Mã vạch barcode', barcode),
                ]),

                // Info Section 2: Pricing details
                _Section('Chính sách giá bán', [
                  _InfoTile('Giá vốn nhập', _currFmt.format(costPrice)),
                  _InfoTile('Giá bán lẻ', _currFmt.format(sellingPrice)),
                  if (wholesalePrice > 0)
                    _InfoTile('Giá bán sỉ', _currFmt.format(wholesalePrice)),
                  if (taxRate.toString().isNotEmpty)
                    _InfoTile('Thuế suất áp dụng', '$taxRate%'),
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
                        style: GoogleFonts.inter(
                          color: c.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          stockStatus,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
                // Info Section 4: Inventory Movements
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Lịch sử xuất nhập',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                movementsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Lỗi tải lịch sử: $e'),
                  ),
                  data: (data) {
                    final items = (data['items'] as List?) ?? [];
                    final currentPage = paginationValue(
                      data,
                      'page',
                      fallback: _movementPage,
                    );
                    final totalPages = paginationValue(
                      data,
                      'totalPages',
                      fallback: 1,
                    );
                    final totalItems = paginationValue(
                      data,
                      'total',
                      fallback: items.length,
                    );
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Chưa có phát sinh tồn kho.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length + 1,
                      separatorBuilder: (_, _) =>
                          Divider(color: c.divider.withValues(alpha: 0.3)),
                      itemBuilder: (_, i) {
                        if (i == items.length) {
                          return AppPaginationBar(
                            currentPage: currentPage,
                            totalPages: totalPages,
                            totalItems: totalItems,
                            itemLabel: 'phát sinh kho',
                            onPageChanged: (page) =>
                                setState(() => _movementPage = page),
                          );
                        }
                        final m = items[i];
                        final isOut = m['movementType'] == 'OUT';
                        final qty = NumberFormat('#,###').format(
                          num.tryParse(m['quantity']?.toString() ?? '0') ?? 0,
                        );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            m['notes'] ?? m['referenceType'] ?? 'Không rõ',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: c.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            m['createdAt']
                                    ?.toString()
                                    .substring(0, 16)
                                    .replaceFirst('T', ' ') ??
                                '',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: c.textSecondary,
                            ),
                          ),
                          trailing: Text(
                            '${isOut ? '-' : '+'}$qty',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isOut
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
      floatingActionButton: detailAsync.hasValue && !compactLayout
          ? FloatingActionButton.extended(
              onPressed: openEdit,
              icon: const AppAssetIcon(
                assetPath: AppAssets.edit,
                size: 19,
                color: Colors.white,
                semanticLabel: 'Chỉnh sửa',
              ),
              label: const Text(
                'Chỉnh sửa',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildTagsRow(dynamic tagsRaw, AppThemeColors c, ThemeData theme) {
    List<String> tags = [];
    if (tagsRaw is List) {
      tags = tagsRaw.map((e) => e.toString()).toList();
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      tags = tagsRaw.split(',').where((e) => e.trim().isNotEmpty).toList();
    }
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: tags
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                t,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  final Color color;

  const _ProductImageFallback({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppAssetIcon(
        assetPath: AppAssets.inventory,
        size: 42,
        color: color,
        semanticLabel: 'Ảnh sản phẩm mặc định',
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
            style: GoogleFonts.manrope(
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
          child: Column(children: children),
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
