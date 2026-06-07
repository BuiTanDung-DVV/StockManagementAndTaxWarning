import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/utils/toast_service.dart';
import '../providers/inventory_provider.dart';

class StockTakeHistoryScreen extends ConsumerWidget {
  const StockTakeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final stAsync = ref.watch(stockTakesProvider(1));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Lịch sử kiểm kê',
          style: GoogleFonts.outfit(
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
          if (items.isEmpty) {
            return const AppEmpty(message: 'Chưa có phiếu kiểm kê nào');
          }
          return Container(
            color: c.card,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: c.divider.withValues(alpha: 0.5)),
              itemBuilder: (_, i) {
                final st = items[i] as Map;
                final code = st['code'] ?? 'ST-${st['id']}';
                final createdAt = st['createdAt']?.toString() ?? '';
                String dateLabel = createdAt;
                if (createdAt.isNotEmpty && createdAt.contains('T')) {
                  try {
                    final dt = DateTime.parse(createdAt).toLocal();
                    dateLabel = DateFormat('dd/MM/yyyy HH:mm').format(dt);
                  } catch (_) {}
                }
                final status = (st['status'] ?? '').toString().toUpperCase();
                final note = st['note']?.toString() ?? '';
                final isCompleted = status == 'COMPLETED';

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
                              style: GoogleFonts.outfit(
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
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        tooltip: 'Xóa phiếu kiểm',
                        onPressed: () {
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
                                final id = st['id'] is int
                                    ? st['id']
                                    : int.tryParse(
                                            st['id']?.toString() ?? '0',
                                          ) ??
                                          0;
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
                        },
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
