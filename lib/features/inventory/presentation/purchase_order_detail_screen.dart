import '../services/purchase_order_pdf_service.dart';
import '../../../core/widgets/order_debt_summary.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/inventory_provider.dart';
import '../providers/purchase_order_detail_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../../../core/network/api_client.dart';
import 'package:go_router/go_router.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class PurchaseOrderDetailScreen extends ConsumerStatefulWidget {
  final Map<dynamic, dynamic> purchaseOrder;
  const PurchaseOrderDetailScreen({super.key, required this.purchaseOrder});
  @override
  ConsumerState<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailState();
}

class _PurchaseOrderDetailState
    extends ConsumerState<PurchaseOrderDetailScreen> {
  PurchaseOrderDetailKey? _origin;
  bool _busy = false;
  bool _exporting = false;
  bool _uncertain = false;
  bool _writeDenied = false;
  String? _mutationError;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _current({bool edit = false}) {
    if (!mounted ||
        _origin == null ||
        '${widget.purchaseOrder['id']}' != '${_origin!.id}') {
      return false;
    }
    if (edit && (_writeDenied || _exporting)) return false;
    final auth = ref.read(authProvider);
    final shop = ref.read(shopProvider);
    return auth.isLoggedIn &&
        !auth.isOfflineSession &&
        '${auth.user?['id']}' == '${_origin!.userId}' &&
        shop.currentShopId == _origin!.shopId &&
        !shop.isAllShops &&
        shop.hasPermission('inventory', edit ? 'edit' : 'view');
  }

  Future<void> _refresh() async {
    final origin = _origin;
    if (origin == null || !_current()) return;
    ref.invalidate(purchaseOrderDetailProvider(origin));
    try {
      await ref.read(purchaseOrderDetailProvider(origin).future);
      if (_current()) {
        setState(() {
          _uncertain = false;
          if (!_writeDenied) _mutationError = null;
        });
      }
    } catch (_) {
      /* The current AsyncValue renders the server error. */
    }
  }

  Future<void> _exportPdf() async {
    final origin = _origin;
    if (origin == null || _busy || _uncertain || _exporting || !_current()) {
      return;
    }
    final shop = ref.read(shopProvider);
    var shopName = shop.currentShopName;
    if (shopName == null || shopName.trim().isEmpty) {
      for (final row in shop.userShops) {
        if ('${row['shopId'] ?? row['id']}' == '${origin.shopId}') {
          shopName = row['shopName']?.toString();
          break;
        }
      }
    }
    final title = shopName?.trim().isNotEmpty == true
        ? shopName!
        : 'Cửa hàng #${origin.shopId}';
    final exporter = ref.read(purchaseOrderPdfExporterProvider);
    setState(() {
      _exporting = true;
      _mutationError = null;
    });
    try {
      ref.invalidate(purchaseOrderDetailProvider(origin));
      final fresh = await ref.read(purchaseOrderDetailProvider(origin).future);
      if (!_current() || origin != _origin) return;
      final bytes = await exporter.build(order: fresh, shopName: title);
      if (!_current() || origin != _origin) return;
      await exporter.save(bytes, exporter.fileName(fresh));
      if (_current()) ToastService.showSuccess('Đã tạo phiếu nhập PDF');
    } catch (_) {
      if (_current()) {
        setState(
          () => _mutationError =
              'Chưa thể xuất phiếu nhập PDF. Hãy kiểm tra kết nối và đối chiếu dữ liệu đơn rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _write(PurchaseOrderDetailKey origin, String action) async {
    if (_busy || _uncertain || origin != _origin || !_current(edit: true)) {
      return;
    }
    if (ref.read(purchaseOrderDetailProvider(origin)).value?['status'] !=
        'PENDING') {
      return;
    }
    setState(() {
      _busy = true;
      _mutationError = null;
    });
    try {
      final repo = ref.read(inventoryRepoProvider);
      if (action == 'DELETE') {
        await repo.deletePurchaseOrderInShop(
          origin.id,
          origin.shopId,
          isCurrentScope: () => _current(edit: true),
        );
      } else {
        await repo.updatePurchaseOrderInShop(origin.id, origin.shopId, {
          'status': action,
        }, isCurrentScope: () => _current(edit: true));
      }
      ref.invalidate(purchaseOrdersProvider);
      ref.invalidate(purchaseOrderQueryProvider);
      if (!mounted || !_current()) return;
      if (action == 'DELETE') {
        ref.invalidate(purchaseOrderDetailProvider(origin));
        ToastService.showSuccess('Đã xóa đơn nhập đang chờ');
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          context.go('/purchase-orders');
        }
      } else {
        await _refresh();
        if (_current()) {
          ToastService.showSuccess(
            action == 'CANCELLED'
                ? 'Đã hủy đơn nhập hàng'
                : 'Đã duyệt nhập kho thành công',
          );
        }
      }
    } catch (error) {
      if (_current()) {
        final code = error is ApiException ? error.statusCode : null;
        setState(() {
          _uncertain = code == null || code >= 500;
          _writeDenied = code == 403 || code == 404;
          if (!_uncertain) {
            _mutationError = error is ApiException
                ? error.message.replaceFirst(RegExp(r'^Validation:\s*'), '')
                : 'Không thực hiện được thao tác đơn nhập.';
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _scrollController.hasClients &&
              _mutationError != null) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
        });
        ToastService.showError(
          _uncertain
              ? 'Chưa xác định được kết quả. Hãy tải lại đơn trước khi thao tác tiếp.'
              : 'Không thực hiện được thao tác. Hãy tải lại để kiểm tra trạng thái đơn.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _message(Widget child) => Scaffold(
    appBar: AppBar(title: const Text('Chi Tiết Đơn Nhập')),
    body: Center(
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse('${widget.purchaseOrder['id']}');
    if (id == null || id <= 0) {
      return const _PurchaseOrderDetailContent(purchaseOrder: {});
    }
    final auth = ref.watch(authProvider);
    final shop = ref.watch(shopProvider);
    final actor = int.tryParse('${auth.user?['id']}');
    final shopId = shop.currentShopId;
    if (auth.isLoading || shop.isLoading) {
      return _message(const CircularProgressIndicator());
    }
    if (!auth.isLoggedIn ||
        actor == null ||
        shopId == null ||
        shop.isAllShops ||
        !shop.hasPermission('inventory')) {
      return _message(
        const Text('Bạn không có quyền xem đơn nhập trong phạm vi hiện tại.'),
      );
    }
    _origin ??= (id: id, shopId: shopId, userId: actor);
    final sourceShopId = int.tryParse('${widget.purchaseOrder['shopId']}');
    if (_origin!.id != id ||
        !_current() ||
        (sourceShopId != null && sourceShopId != shopId)) {
      return _message(
        const Text(
          'Đã đổi tài khoản hoặc cửa hàng. Hãy mở lại đơn từ danh sách.',
        ),
      );
    }
    final detail = ref.watch(purchaseOrderDetailProvider(_origin!));
    final origin = _origin!;
    return detail.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => _message(const CircularProgressIndicator()),
      error: (error, _) => error is ApiException && error.statusCode == 404
          ? const _PurchaseOrderDetailContent(purchaseOrder: {})
          : _message(
              AppInlineError(
                message: error is ApiException && error.statusCode == 403
                    ? 'Không còn quyền xem đơn nhập này.'
                    : 'Không tải được chi tiết đơn nhập. Hãy kiểm tra kết nối và thử lại.',
                onRetry: _refresh,
              ),
            ),
      data: (order) => Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_uncertain)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: _busy ? null : _refresh,
                child: const Text(
                  'Kết quả chưa xác định — tải lại đơn trước khi thao tác tiếp',
                ),
              ),
            ),
          Expanded(
            child: _PurchaseOrderDetailContent(
              purchaseOrder: order,
              mutationError: _mutationError,
              exporting: _exporting,
              onExport: !_busy && !_uncertain && !_exporting
                  ? _exportPdf
                  : null,
              scrollController: _scrollController,
              canEdit:
                  !_busy &&
                  !_exporting &&
                  !_uncertain &&
                  !_writeDenied &&
                  shop.hasPermission('inventory', 'edit'),
              onRefresh: _exporting ? null : _refresh,
              onStatus: (action) => _write(origin, action),
              onDelete: () => _write(origin, 'DELETE'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrderDetailContent extends ConsumerWidget {
  final Map<dynamic, dynamic> purchaseOrder;
  final bool canEdit;
  final bool exporting;
  final Future<void> Function()? onExport;
  final String? mutationError;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;
  final Future<void> Function(String)? onStatus;
  final Future<void> Function()? onDelete;
  const _PurchaseOrderDetailContent({
    required this.purchaseOrder,
    this.canEdit = false,
    this.exporting = false,
    this.onExport,
    this.mutationError,
    this.scrollController,
    this.onRefresh,
    this.onStatus,
    this.onDelete,
  });

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      context.go('/purchase-orders');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);

    if (purchaseOrder.isEmpty) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 60,
          leading: AppNavigationBackLeading(onPressed: () => _back(context)),
          title: Text(
            'Chi Tiết Đơn Nhập',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: c.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: AppEmpty(
            visual: AppEmptyVisual.document,
            message: 'Không tìm thấy thông tin đơn nhập hàng',
            subtitle: 'Dữ liệu đơn hàng không tồn tại hoặc đã bị xóa.',
            action: ElevatedButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                } else {
                  context.go('/purchase-orders');
                }
              },
              icon: const AppIcon(Icons.arrow_back),
              label: const Text('Quay lại'),
            ),
          ),
        ),
      );
    }

    final poItems = (purchaseOrder['items'] as List?) ?? [];
    final code =
        purchaseOrder['orderCode'] ??
        purchaseOrder['code'] ??
        'PO-${purchaseOrder['id']}';
    final supplierName =
        purchaseOrder['supplier']?['name'] ??
        purchaseOrder['supplierName'] ??
        'Không rõ nhà cung cấp';
    final orderDateKey =
        purchaseOrder['orderDate']?.toString().split('T').first ?? '';
    final parsedOrderDate = DateTime.tryParse(orderDateKey);
    final orderDate = parsedOrderDate == null
        ? orderDateKey
        : DateFormat('dd/MM/yyyy').format(parsedOrderDate);
    final invoiceNumber = purchaseOrder['invoiceNumber'] ?? '';
    final status = (purchaseOrder['status'] ?? '').toString().toUpperCase();

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

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leadingWidth: 60,
            leading: AppNavigationBackLeading(onPressed: () => _back(context)),
            title: Text(
              'Chi Tiết Đơn Nhập',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: c.textPrimary,
              ),
            ),
            centerTitle: true,
            actions: [
              if (constraints.maxWidth < 600)
                PopupMenuButton<String>(
                  tooltip: 'Tác vụ đơn nhập',
                  icon: const AppIcon(Icons.more_vert),
                  onSelected: (action) async {
                    if (action == 'pdf') await onExport?.call();
                    if (action == 'refresh') await onRefresh?.call();
                    if (action == 'delete' && context.mounted) {
                      await _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'pdf',
                      enabled: onExport != null && !exporting,
                      child: const Text('Tải phiếu PDF'),
                    ),
                    PopupMenuItem(
                      value: 'refresh',
                      enabled: onRefresh != null,
                      child: const Text('Tải lại đơn nhập'),
                    ),
                    if (status == 'PENDING' && canEdit)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Xóa đơn nhập đang chờ'),
                      ),
                  ],
                )
              else ...[
                TextButton.icon(
                  onPressed: onExport,
                  icon: exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const AppIcon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(exporting ? 'Đang tạo...' : 'Xuất PDF'),
                ),
                IconButton(
                  tooltip: 'Tải lại đơn nhập',
                  onPressed: onRefresh,
                  icon: const AppIcon(Icons.refresh),
                ),
                if (status == 'PENDING' && canEdit)
                  IconButton(
                    icon: const AppIcon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'Xóa đơn nhập đang chờ',
                    onPressed: () => _confirmDelete(context, ref),
                  ),
              ],
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: RefreshIndicator(
                onRefresh: onRefresh ?? () async {},
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mutationError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.06),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.25),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mutationError!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textPrimary,
                                ),
                              ),
                              if (onRefresh != null)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: onRefresh,
                                    icon: const AppIcon(
                                      Icons.refresh,
                                      size: 16,
                                    ),
                                    label: const Text('Tải lại đơn'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // General Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: c.divider.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow('Mã đơn hàng', code.toString(), c),
                            if (orderDate.isNotEmpty)
                              _buildInfoRow('Ngày nhập hàng', orderDate, c),
                            _buildInfoRow('Nhà cung cấp', supplierName, c),
                            if (invoiceNumber.isNotEmpty)
                              _buildInfoRow('Số hóa đơn', invoiceNumber, c),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Trạng thái',
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
                                    statusLabel,
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Danh sách sản phẩm',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (poItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: AppEmpty(
                            visual: AppEmptyVisual.inventory,
                            message: 'Đơn nhập không có sản phẩm nào',
                            subtitle:
                                'Vui lòng kiểm tra lại chi tiết các mặt hàng trong đơn.',
                          ),
                        )
                      else
                        ...poItems.map((item) {
                          final itemName =
                              item['product']?['name'] ??
                              item['productName'] ??
                              item['name'] ??
                              'Sản phẩm ${item['productId'] ?? ''}';
                          final qty = asDouble(item['quantity']);
                          final qtyStr = (qty % 1 == 0)
                              ? qty.toInt().toString()
                              : qty.toString();
                          final unitPrice = asDouble(item['unitPrice']);
                          final subtotal = asDouble(
                            item['subtotal'] ?? (qty * unitPrice),
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: c.divider.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                ProductThumbnail(
                                  imageUrl:
                                      item['product']?['imageUrl']
                                          ?.toString() ??
                                      item['imageUrl']?.toString(),
                                  name: item['product']?['name']?.toString(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemName,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: c.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SL: $qtyStr x ${_currFmt.format(unitPrice)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: c.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _currFmt.format(subtotal),
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    color: c.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.divider),
                        ),
                        child: OrderDebtSummary(
                          order: purchaseOrder,
                          purchase: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: status == 'PENDING' && canEdit
              ? Container(
                  key: const ValueKey('purchase-actions'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.card,
                    border: Border(
                      top: BorderSide(color: c.divider.withValues(alpha: 0.4)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Align(
                          alignment: Alignment.centerRight,
                          heightFactor: 1,
                          child: SizedBox(
                            width: 480,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final bool?
                                      confirm = await AppConfirmModal.show(
                                        context,
                                        title: 'Xác nhận hủy đơn',
                                        message:
                                            'Bạn có chắc chắn muốn hủy đơn nhập hàng này? Đơn sẽ chuyển sang trạng thái Đã hủy.',
                                        confirmText: 'Hủy đơn',
                                        cancelText: 'Quay lại',
                                      );

                                      if (confirm == true) {
                                        await onStatus?.call('CANCELLED');
                                      }
                                    },
                                    icon: const AppIcon(
                                      Icons.cancel_outlined,
                                      size: 18,
                                      color: AppColors.danger,
                                    ),
                                    label: Text(
                                      'Hủy đơn',
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppColors.danger,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final bool?
                                      confirm = await AppConfirmModal.show(
                                        context,
                                        title: 'Xác nhận duyệt',
                                        message:
                                            'Bạn có chắc chắn muốn duyệt nhập kho đơn hàng này? Số lượng tồn kho sẽ được cộng thêm và không thể hoàn tác.',
                                        confirmText: 'Duyệt',
                                        cancelText: 'Hủy',
                                      );

                                      if (confirm == true) {
                                        await onStatus?.call('COMPLETED');
                                      }
                                    },
                                    icon: const AppIcon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      'Duyệt Nhập Kho',
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, AppThemeColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: c.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: c.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final poId = purchaseOrder['id'] is int
        ? purchaseOrder['id']
        : int.tryParse(purchaseOrder['id']?.toString() ?? '0') ?? 0;
    final code =
        purchaseOrder['orderCode'] ?? purchaseOrder['code'] ?? 'PO-$poId';
    final supplierName =
        purchaseOrder['supplier']?['name'] ??
        purchaseOrder['supplierName'] ??
        '';
    final orderDate =
        purchaseOrder['orderDate']?.toString().split('T').first ?? '';
    String dateLabel = orderDate;
    if (orderDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(orderDate).toLocal();
        dateLabel = DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {}
    }

    final recordInfo = [
      code,
      if (supplierName.toString().isNotEmpty) supplierName.toString(),
      if (dateLabel.isNotEmpty) dateLabel,
    ].join(' - ');

    final bool? confirm = await AppConfirmModal.show(
      context,
      title: 'Xóa đơn nhập',
      message:
          'Bạn có chắc chắn muốn xóa đơn nhập đang chờ "$recordInfo"? Thao tác này sẽ xóa bản ghi đang chờ xử lý và sẽ không có nghiệp vụ nhập kho nào được thực hiện.',
      confirmText: 'Xóa đơn nhập',
      cancelText: 'Hủy',
      isDestructive: true,
    );

    if (confirm == true) {
      await onDelete?.call();
    }
  }
}
