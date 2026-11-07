import 'dart:async';
import '../../../core/assets/app_icon.dart';
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
import '../../../core/widgets/app_navigation_back_button.dart';
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
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  String _search = '';
  String _status = '';
  ({int page, String search, String status}) get _query =>
      (page: _page, search: _search, status: _status);

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _searchTimer?.cancel();
    setState(() {});
    if (value.trim() == _search) return;
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _search = value.trim();
          _page = 1;
        });
      }
    });
  }

  void _clearFilters() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _search = '';
      _status = '';
      _page = 1;
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(purchaseOrdersProvider);
    ref.invalidate(purchaseOrderQueryProvider(_query));
    try {
      await ref.read(purchaseOrderQueryProvider(_query).future);
    } catch (_) {
      /* Error is rendered by AsyncValue below. */
    }
  }

  Widget _filters(AsyncValue<Map<String, dynamic>> data) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _searchChanged,
          onSubmitted: (_) {
            _searchTimer?.cancel();
            setState(() {
              _search = _searchController.text.trim();
              _page = 1;
            });
          },
          decoration: InputDecoration(
            labelText: 'Tìm đơn nhập',
            hintText: 'Mã đơn, hóa đơn, nhà cung cấp, sản phẩm hoặc ghi chú',
            helperText: 'Tìm trên toàn bộ dữ liệu cửa hàng',
            prefixIcon: const AppIcon(Icons.search, size: 18),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    icon: const AppIcon(Icons.close, size: 18),
                    onPressed: () {
                      _searchTimer?.cancel();
                      _searchController.clear();
                      setState(() {
                        _search = '';
                        _page = 1;
                      });
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                key: ValueKey(_status),
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Tất cả trạng thái')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Chờ xử lý')),
                  DropdownMenuItem(
                    value: 'COMPLETED',
                    child: Text('Hoàn thành'),
                  ),
                  DropdownMenuItem(value: 'CANCELLED', child: Text('Đã hủy')),
                ],
                onChanged: (value) {
                  _searchTimer?.cancel();
                  setState(() {
                    _status = value ?? '';
                    _search = _searchController.text.trim();
                    _page = 1;
                  });
                },
              ),
            ),
            if (_searchController.text.isNotEmpty || _status.isNotEmpty)
              TextButton(onPressed: _clearFilters, child: const Text('Bỏ lọc')),
            if (data.hasValue)
              Text('${asNum(data.value?['total']).toInt()} đơn nhập'),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final poAsync = ref.watch(purchaseOrderQueryProvider(_query));
    final compactLayout = MediaQuery.sizeOf(context).width < 720;
    Future<void> openForm() async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PurchaseOrderFormScreen()),
      );
      if (mounted) {
        await _refresh();
      }
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
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
          if (!compactLayout)
            AppPrimaryPageAction(
              label: 'Tạo đơn nhập',
              assetPath: AppAssets.add,
              onPressed: openForm,
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: compactLayout
          ? FloatingActionButton.extended(
              heroTag: 'purchase-order-add-fab',
              onPressed: openForm,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              icon: const AppIcon(
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
            )
          : null,
      body: Column(
        children: [
          _filters(poAsync),
          Expanded(
            child: poAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppInlineError(
                    message:
                        'Không tải được danh sách đơn hàng. Vui lòng thử lại sau.',
                    onRetry: _refresh,
                  ),
                ),
              ),
              data: (data) {
                final items = (data['items'] as List?) ?? [];
                final currentPage = paginationValue(
                  data,
                  'page',
                  fallback: _page,
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
                if (items.isEmpty &&
                    _page > (totalPages > 0 ? totalPages : 1)) {
                  final requested = _query;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _query == requested) {
                      setState(() => _page = totalPages > 0 ? totalPages : 1);
                    }
                  });
                }
                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        AppEmpty(
                          visual: AppEmptyVisual.document,
                          message: _search.isNotEmpty || _status.isNotEmpty
                              ? 'Không có đơn nhập khớp bộ lọc.'
                              : 'Chưa có đơn mua hàng nào được tạo',
                          action: _search.isNotEmpty || _status.isNotEmpty
                              ? TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Bỏ lọc'),
                                )
                              : null,
                        ),
                      ],
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 720;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 16 : 0,
                            vertical: isDesktop ? 16 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(
                              isDesktop ? 20 : 0,
                            ),
                            border: isDesktop
                                ? Border.all(
                                    color: c.divider.withValues(alpha: 0.5),
                                  )
                                : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              itemCount: items.length + 1,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: c.divider.withValues(alpha: 0.5),
                              ),
                              itemBuilder: (_, i) {
                                if (i == items.length) {
                                  return AppPaginationBar(
                                    currentPage: currentPage,
                                    totalPages: totalPages,
                                    totalItems: totalItems,
                                    itemLabel: 'đơn nhập hàng',
                                    onPageChanged: (page) =>
                                        setState(() => _page = page),
                                  );
                                }
                                final po = items[i] as Map;
                                final code =
                                    po['orderCode'] ??
                                    po['code'] ??
                                    'PO-${po['id'] ?? i}';
                                final supplierName =
                                    po['supplier']?['name'] ??
                                    po['supplierName'] ??
                                    'Không rõ nhà cung cấp';
                                final totalAmount = asDouble(po['totalAmount']);
                                final orderDate =
                                    po['orderDate']
                                        ?.toString()
                                        .split('T')
                                        .first ??
                                    '';
                                final invoiceNumber = po['invoiceNumber'] ?? '';
                                final status = (po['status'] ?? '')
                                    .toString()
                                    .toUpperCase();

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
                                    statusLabel = status.isNotEmpty
                                        ? status
                                        : 'N/A';
                                }

                                return GestureDetector(
                                  onTap: () {
                                    context.go(
                                      Uri(
                                        path: '/purchase-orders/detail',
                                        queryParameters: {
                                          'id': '${po['id']}',
                                          if (po['shopId'] != null)
                                            'shopId': '${po['shopId']}',
                                        },
                                      ).toString(),
                                      extra: po,
                                    );
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppColors.info.withValues(
                                                alpha: 0.08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const AppIcon(
                                              Icons.move_to_inbox_rounded,
                                              color: AppColors.info,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        code.toString(),
                                                        style:
                                                            GoogleFonts.manrope(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14,
                                                              color:
                                                                  c.textPrimary,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: statusColor
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        statusLabel,
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontSize: 9,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  statusColor,
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
