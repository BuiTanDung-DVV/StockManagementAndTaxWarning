import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/product_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import 'product_form_screen.dart';
import 'widgets/product_details_content.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int id;
  final String returnRoute;

  const ProductDetailScreen({
    super.key,
    required this.id,
    this.returnRoute = '/products',
  });

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
        automaticallyImplyLeading: false,
        leadingWidth: 60,
        leading: AppNavigationBackLeading(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(widget.returnRoute),
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
          if (!compactLayout && detailAsync.hasValue)
            AppPrimaryPageAction(
              label: 'Chỉnh sửa',
              assetPath: AppAssets.edit,
              onPressed: openEdit,
            ),
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
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: c.textMuted),
                const SizedBox(height: 12),
                Text(
                  'Không thể tải thông tin sản phẩm.\n'
                  'Sản phẩm có thể đã bị xóa hoặc bạn không có quyền xem.',
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
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(widget.returnRoute),
                  child: const Text('Quay lại danh sách'),
                ),
              ],
            ),
          ),
        ),
        data: (p) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductDetailsContent(product: p),
                const SizedBox(height: 20),

                // Info Section: Inventory Movements
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
    );
  }
}
