import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/utils/toast_service.dart';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: c.textMuted),
                const SizedBox(height: 12),
                Text(
                  'Không tải được lịch sử kiểm kê\n$e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(stockTakesProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
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
              message: 'Chưa có phiếu kiểm kê nào',
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
                    itemLabel: 'phiếu kiểm kê',
                    onPageChanged: (page) => setState(() => _page = page),
                  );
                }
                final st = items[i] as Map;
                final code =
                    st['stockTakeCode'] ?? st['code'] ?? 'ST-${st['id']}';
                final stockTakeDate =
                    (st['stockTakeDate'] ?? st['createdAt'])?.toString() ?? '';
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

                return Padding(
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
                                : int.tryParse(st['id']?.toString() ?? '0') ??
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
                                  'Không thể hoàn tất phiếu: $e',
                                );
                              }
                              return;
                            }
                            if (action == 'cancel') {
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
                                  'Không thể hủy phiếu: $e',
                                );
                              }
                              return;
                            }
                            if (action == 'delete') {
                              AppConfirmModal.show(
                                context,
                                title: 'Xóa phiếu kiểm',
                                message:
                                    'Bạn có chắc chắn muốn xóa phiếu kiểm kê này?',
                                confirmText: 'Xóa',
                                cancelText: 'Hủy',
                              ).then((confirm) async {
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
                                    ToastService.showError('Lỗi: $e');
                                  }
                                }
                              });
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
