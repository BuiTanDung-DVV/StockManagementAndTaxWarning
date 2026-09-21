import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/inventory_provider.dart';

class StockTakeHistoryScreen extends ConsumerStatefulWidget {
  const StockTakeHistoryScreen({super.key});

  @override
  ConsumerState<StockTakeHistoryScreen> createState() =>
      _StockTakeHistoryScreenState();
}

class _StockTakeHistoryScreenState
    extends ConsumerState<StockTakeHistoryScreen> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final stAsync = ref.watch(stockTakesProvider(_page));

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
          'Lịch sử kiểm kê',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: stAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppInlineError(
              message: 'Không tải được lịch sử kiểm kê. Vui lòng thử lại sau.',
              onRetry: () => ref.invalidate(stockTakesProvider),
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
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(stockTakesProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  AppEmpty(
                    visual: AppEmptyVisual.document,
                    message: 'Chưa có phiếu kiểm kê nào',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(stockTakesProvider),
            child: Container(
              color: c.card,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: c.divider.withValues(alpha: 0.5)),
                itemBuilder: (_, i) {
                  if (i == items.length) {
                    return AppPaginationBar(
                      currentPage: currentPage,
                      totalPages: totalPages,
                      totalItems: totalItems,
                      itemLabel: 'phiếu kiểm kê',
                      onPageChanged: (page) => setState(() => _page = page),
                    );
                  }
                  final st = items[i] as Map;
                  final code =
                      st['stockTakeCode'] ?? st['code'] ?? 'ST-${st['id']}';
                  final stockTakeDate =
                      (st['stockTakeDate'] ?? st['createdAt'])?.toString() ??
                      '';
                  String dateLabel = stockTakeDate;
                  if (stockTakeDate.isNotEmpty) {
                    try {
                      final dt = DateTime.parse(stockTakeDate).toLocal();
                      dateLabel = stockTakeDate.contains('T')
                          ? DateFormat('dd/MM/yyyy HH:mm').format(dt)
                          : DateFormat('dd/MM/yyyy').format(dt);
                    } catch (_) {}
                  }
                  final status = (st['status'] ?? '').toString().toUpperCase();
                  final note = (st['notes'] ?? st['note'])?.toString() ?? '';
                  final isCompleted = status == 'COMPLETED';
                  final isDraft = status == 'DRAFT' || status.isEmpty;
                  final stockTakeItems = (st['items'] as List?) ?? const [];
                  final differenceCount = stockTakeItems.where((item) {
                    if (item is! Map) return false;
                    final difference = num.tryParse(
                      item['difference']?.toString() ?? '0',
                    );
                    return difference != null && difference != 0;
                  }).length;
                  final statusLabel = isCompleted
                      ? 'Đã hoàn tất'
                      : status == 'CANCELLED'
                      ? 'Đã hủy'
                      : 'Bản nháp';

                  return InkWell(
                    onTap: () => _showDetailModal(context, st),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  (isCompleted
                                          ? AppColors.success
                                          : AppColors.warning)
                                      .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.fact_check_rounded,
                              color: isCompleted
                                  ? AppColors.success
                                  : AppColors.warning,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  code,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: c.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  statusLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isCompleted
                                        ? AppColors.success
                                        : isDraft
                                        ? AppColors.warning
                                        : c.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${stockTakeItems.length} sản phẩm • $differenceCount có chênh lệch',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: differenceCount > 0
                                        ? AppColors.danger
                                        : c.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (note.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    note,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: c.textMuted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isDraft)
                            PopupMenuButton<String>(
                              tooltip: 'Thao tác phiếu kiểm kê',
                              onSelected: (action) async {
                                final id = st['id'] is int
                                    ? st['id'] as int
                                    : int.tryParse(
                                            st['id']?.toString() ?? '0',
                                          ) ??
                                          0;
                                if (id <= 0) return;
                                if (action == 'complete') {
                                  final confirm = await AppConfirmModal.show(
                                    context,
                                    title: 'Hoàn tất kiểm kê',
                                    message:
                                        'Hệ thống sẽ đối chiếu lại tồn kho hiện tại trong DB và cập nhật theo số thực tế đã nhập. Bạn muốn tiếp tục?',
                                    confirmText: 'Hoàn tất',
                                    cancelText: 'Quay lại',
                                  );
                                  if (confirm != true) return;
                                  try {
                                    await ref
                                        .read(inventoryRepoProvider)
                                        .updateStockTakeStatus(id, 'COMPLETED');
                                    ToastService.showSuccess(
                                      'Đã hoàn tất và cập nhật tồn kho',
                                    );
                                    ref.invalidate(stockTakesProvider);
                                    ref.invalidate(stockProvider);
                                    ref.invalidate(stockPageProvider);
                                    ref.invalidate(lowStockProvider);
                                  } catch (e) {
                                    ToastService.showError(
                                      'Không thể hoàn tất phiếu kiểm kê. Vui lòng thử lại sau.',
                                    );
                                  }
                                  return;
                                }
                                if (action == 'cancel') {
                                  final confirm = await AppConfirmModal.show(
                                    context,
                                    title: 'Hủy phiếu kiểm kê',
                                    message:
                                        'Bạn có chắc chắn muốn hủy phiếu kiểm kê này? Dữ liệu kiểm đếm sẽ không được cập nhật vào kho.',
                                    confirmText: 'Hủy phiếu',
                                    cancelText: 'Quay lại',
                                  );
                                  if (confirm != true) return;
                                  try {
                                    await ref
                                        .read(inventoryRepoProvider)
                                        .updateStockTakeStatus(id, 'CANCELLED');
                                    ToastService.showSuccess(
                                      'Đã hủy phiếu kiểm kê',
                                    );
                                    ref.invalidate(stockTakesProvider);
                                  } catch (e) {
                                    ToastService.showError(
                                      'Không thể hủy phiếu kiểm kê. Vui lòng thử lại sau.',
                                    );
                                  }
                                  return;
                                }
                                if (action == 'delete') {
                                  final confirm = await AppConfirmModal.show(
                                    context,
                                    title: 'Xóa phiếu kiểm',
                                    message:
                                        'Bạn có chắc chắn muốn xóa vĩnh viễn phiếu kiểm kê này?',
                                    confirmText: 'Xóa',
                                    cancelText: 'Hủy',
                                  );
                                  if (confirm == true) {
                                    try {
                                      await ref
                                          .read(inventoryRepoProvider)
                                          .deleteStockTake(id);
                                      ToastService.showSuccess(
                                        'Xóa phiếu kiểm thành công',
                                      );
                                      ref.invalidate(stockTakesProvider);
                                      ref.invalidate(stockProvider);
                                    } catch (e) {
                                      ToastService.showError(
                                        'Không thể xóa phiếu kiểm kê. Vui lòng thử lại sau.',
                                      );
                                    }
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'complete',
                                  child: ListTile(
                                    leading: Icon(Icons.task_alt_rounded),
                                    title: Text('Hoàn tất phiếu'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'cancel',
                                  child: ListTile(
                                    leading: Icon(Icons.cancel_outlined),
                                    title: Text('Hủy phiếu'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Xóa bản nháp'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDetailModal(BuildContext context, Map st) {
    final c = AppThemeColors.of(context);
    final code = st['stockTakeCode'] ?? st['code'] ?? 'ST-${st['id']}';
    final items = (st['items'] as List?) ?? const [];
    final status = (st['status'] ?? '').toString().toUpperCase();
    final note = (st['notes'] ?? st['note'])?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chi tiết $code',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: c.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (status == 'COMPLETED'
                                ? AppColors.success
                                : status == 'CANCELLED'
                                ? AppColors.danger
                                : AppColors.warning)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status == 'COMPLETED'
                        ? 'Đã hoàn tất'
                        : status == 'CANCELLED'
                        ? 'Đã hủy'
                        : 'Bản nháp',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: status == 'COMPLETED'
                          ? AppColors.success
                          : status == 'CANCELLED'
                          ? AppColors.danger
                          : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ghi chú: $note',
                style: TextStyle(
                  fontSize: 12,
                  color: c.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Danh sách sản phẩm kiểm kê (${items.length})',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: AppEmpty(
                        visual: AppEmptyVisual.inventory,
                        message: 'Không có sản phẩm nào trong phiếu này',
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: c.divider),
                      itemBuilder: (_, idx) {
                        final item = items[idx] is Map ? items[idx] as Map : {};
                        final pName =
                            item['productName'] ??
                            item['name'] ??
                            item['product']?['name'] ??
                            'Sản phẩm ${item['productId'] ?? idx + 1}';
                        final sysQty = parseQuantity(
                          item['systemQty'] ?? item['systemQuantity'],
                        );
                        final actQty = parseQuantity(
                          item['actualQty'] ?? item['actualQuantity'],
                        );
                        final diff = item['difference'] != null
                            ? parseQuantity(item['difference'])
                            : (actQty - sysQty);
                        final sysQtyStr = (sysQty % 1 == 0)
                            ? sysQty.toInt().toString()
                            : sysQty.toString();
                        final actQtyStr = (actQty % 1 == 0)
                            ? actQty.toInt().toString()
                            : actQty.toString();
                        final diffStr = (diff % 1 == 0)
                            ? diff.toInt().toString()
                            : diff.toString();

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  pName.toString(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Hệ thống: $sysQtyStr\nThực tế: $actQtyStr',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  diff > 0
                                      ? '+$diffStr (Thừa)'
                                      : diff < 0
                                      ? '$diffStr (Thiếu)'
                                      : 'Khớp (0)',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: diff > 0
                                        ? AppColors.success
                                        : diff < 0
                                        ? AppColors.danger
                                        : c.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
