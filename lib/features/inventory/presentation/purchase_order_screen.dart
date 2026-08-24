import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../providers/inventory_provider.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import 'purchase_order_form_screen.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class PurchaseOrderScreen extends ConsumerStatefulWidget {
  const PurchaseOrderScreen({super.key});

  @override
  ConsumerState<PurchaseOrderScreen> createState() =>
      _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends ConsumerState<PurchaseOrderScreen> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final poAsync = ref.watch(purchaseOrdersProvider(_page));
    final compactLayout = MediaQuery.sizeOf(context).width < 720;
    void openForm() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PurchaseOrderFormScreen()),
    );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Đơn Mua Nhập Hàng',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'purchase_order'),
          if (compactLayout)
            AppPrimaryHeaderAction(
              label: 'Tạo đơn nhập',
              assetPath: AppAssets.add,
              heroTag: 'purchase-order-add-compact',
              onPressed: openForm,
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: compactLayout
          ? null
          : FloatingActionButton.extended(
              onPressed: openForm,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              icon: const Icon(
                Icons.shopping_cart_checkout_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                'Tạo Đơn Nhập',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              backgroundColor: AppColors.primary,
            ),
      body: poAsync.when(
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
                  'Không tải được danh sách đơn hàng\n$e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(purchaseOrdersProvider),
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
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          final currentPage = paginationValue(data, 'page', fallback: _page);
          final totalPages = paginationValue(data, 'totalPages', fallback: 1);
          final totalItems = paginationValue(
            data,
            'total',
            fallback: items.length,
          );
          if (items.isEmpty) {
            return const AppEmpty(
              visual: AppEmptyVisual.document,
              message: 'Chưa có đơn mua hàng nào được tạo',
            );
          }
          return Container(
            color: c.card,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: c.divider.withValues(alpha: 0.5)),
              itemBuilder: (_, i) {
                if (i == items.length) {
                  return AppPaginationBar(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    totalItems: totalItems,
                    itemLabel: 'đơn nhập hàng',
                    onPageChanged: (page) => setState(() => _page = page),
                  );
                }
                final po = items[i] as Map;
                final code =
                    po['orderCode'] ?? po['code'] ?? 'PO-${po['id'] ?? i}';
                final supplierName =
                    po['supplier']?['name'] ??
                    po['supplierName'] ??
                    'Không rõ nhà cung cấp';
                final totalAmount = asDouble(po['totalAmount']);
                final orderDate =
                    po['orderDate']?.toString().split('T').first ?? '';
                final invoiceNumber = po['invoiceNumber'] ?? '';
                final status = (po['status'] ?? '').toString().toUpperCase();

                Color statusColor;
                String statusLabel;
                switch (status) {
                  case 'COMPLETED':
                    statusColor = AppColors.success;
                    statusLabel = 'Hoàn thành';
                    break;
                  case 'CANCELLED':
                    statusColor = AppColors.danger;
                    statusLabel = 'Đã hủy';
                    break;
                  case 'PENDING':
                    statusColor = AppColors.warning;
                    statusLabel = 'Chờ xử lý';
                    break;
                  default:
                    statusColor = AppColors.info;
                    statusLabel = status.isNotEmpty ? status : 'N/A';
                }

                return GestureDetector(
                  onTap: () =>
                      context.push('/purchase-orders/detail', extra: po),
                  child: Container(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.move_to_inbox_rounded,
                              color: AppColors.info,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      code.toString(),
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'NCC: $supplierName',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${orderDate.isNotEmpty ? orderDate : ''}${invoiceNumber.isNotEmpty ? ' • HĐ: $invoiceNumber' : ''}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: c.textMuted,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _currFmt.format(totalAmount),
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
