import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_service.dart';
import '../providers/system_provider.dart';

class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final logsAsync = ref.watch(activityLogsProvider(1));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Nhật ký hoạt động', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: c.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.filter_list_rounded), onPressed: () {
            ToastService.showSuccess('Tính năng bộ lọc đang được phát triển');
          })
        ],
      ),
      body: logsAsync.when(
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 64, color: c.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Chưa có nhật ký hoạt động', style: GoogleFonts.inter(color: c.textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(activityLogsProvider),
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final log = items[i] as Map;
                final message = (log['message'] ?? log['action'] ?? 'Hoạt động').toString();
                final actor = (log['actor'] ?? log['user']?['username'] ?? 'Hệ thống').toString();
                final rawDate = (log['createdAt'] ?? log['created_at'] ?? '').toString();
                final rawMetadata = log['details'] ?? log['metadata'];
                String formattedMetadata = '';
                if (rawMetadata != null) {
                  try {
                    dynamic parsed = rawMetadata;
                    if (rawMetadata is String && rawMetadata.isNotEmpty) {
                      parsed = jsonDecode(rawMetadata);
                    }
                    if (parsed is Map) {
                      final List<String> parts = [];
                      parsed.forEach((key, value) {
                        if (value != null && value.toString().isNotEmpty) {
                          final translatedKey = _translateLogKey(key.toString());
                          String displayValue = value.toString();
                          if (value is Map || value is List) {
                            try {
                              displayValue = const JsonEncoder.withIndent('  ').convert(value);
                            } catch (_) {}
                          }
                          parts.add('• $translatedKey: $displayValue');
                        }
                      });
                      formattedMetadata = parts.join('\n');
                    } else if (parsed is List) {
                      formattedMetadata = 'Có ${parsed.length} mục thay đổi';
                    } else {
                      formattedMetadata = parsed.toString();
                    }
                  } catch (_) {
                    formattedMetadata = rawMetadata.toString();
                  }
                }
                
                String formattedDate = rawDate;
                String timeOnly = '';
                try {
                  final dt = DateTime.parse(rawDate).toLocal();
                  formattedDate = DateFormat('dd/MM/yyyy').format(dt);
                  timeOnly = DateFormat('HH:mm').format(dt);
                } catch (_) {}

                IconData actionIcon = Icons.history_rounded;
                Color actionColor = AppColors.primary;
                if (message.toLowerCase().contains('tạo') || message.toLowerCase().contains('thêm') || message.toLowerCase().contains('create')) {
                  actionIcon = Icons.add_circle_outline_rounded;
                  actionColor = AppColors.success;
                } else if (message.toLowerCase().contains('xóa') || message.toLowerCase().contains('delete') || message.toLowerCase().contains('hủy')) {
                  actionIcon = Icons.delete_outline_rounded;
                  actionColor = AppColors.danger;
                } else if (message.toLowerCase().contains('cập nhật') || message.toLowerCase().contains('sửa') || message.toLowerCase().contains('update')) {
                  actionIcon = Icons.edit_outlined;
                  actionColor = AppColors.warning;
                } else if (message.toLowerCase().contains('đăng nhập') || message.toLowerCase().contains('login')) {
                  actionIcon = Icons.login_rounded;
                  actionColor = AppColors.info;
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.divider.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(actionIcon, size: 20, color: actionColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary, height: 1.4),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded, size: 14, color: c.textSecondary),
                                const SizedBox(width: 4),
                                Text(actor, style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            if (formattedMetadata.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: c.bg.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: c.divider.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  formattedMetadata,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: AppColors.info,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(timeOnly, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: c.textPrimary)),
                          const SizedBox(height: 2),
                          Text(formattedDate, style: GoogleFonts.inter(fontSize: 11, color: c.textMuted)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: AppColors.danger))),
      ),
    );
  }
}

String _translateLogKey(String key) {
  final Map<String, String> map = {
    'name': 'Tên',
    'quantity': 'Số lượng',
    'price': 'Giá',
    'sellingPrice': 'Giá bán',
    'costPrice': 'Giá vốn',
    'amount': 'Tổng tiền',
    'status': 'Trạng thái',
    'paymentMethod': 'Phương thức T/T',
    'note': 'Ghi chú',
    'customerName': 'Tên KH',
    'phone': 'SĐT',
    'address': 'Địa chỉ',
    'discount': 'Giảm giá',
    'taxAmount': 'Thuế',
    'productName': 'Tên sản phẩm',
    'sku': 'Mã SKU',
    'stock': 'Tồn kho',
  };
  return map[key] ?? key;
}
