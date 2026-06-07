import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../customers/providers/customer_provider.dart';

class DebtAgingScreen extends ConsumerWidget {
  const DebtAgingScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final asOf = DateTime.now().toIso8601String().split('T').first;
    final agingAsync = ref.watch(debtAgingProvider(asOf));
    final overdueAsync = ref.watch(overdueDebtsProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Phân tích Tuổi nợ KH',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'debt_aging'),
          IconButton(
            icon: const Icon(Icons.file_download_rounded),
            onPressed: () {
              ToastService.showSuccess(
                'Xuất báo cáo PDF/Excel sẽ sớm khả dụng trong bản cập nhật kế tiếp!',
              );
            },
          ),
        ],
      ),
      body: agingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Lỗi: $e', style: TextStyle(color: AppColors.danger)),
        ),
        data: (agingData) {
          final buckets = agingData['buckets'] as Map<String, dynamic>? ?? {};
          final summary = agingData['summary'] as Map<String, dynamic>? ?? {};
          final customers = (agingData['customers'] as List?) ?? const [];
          final totalDebt = asNum(agingData['totalDebt']);
          final current = asNum(buckets['current']);
          final days30 = asNum(buckets['past30'] ?? buckets['days30']);
          final days60 = asNum(buckets['past60'] ?? buckets['days60']);
          final over90 = asNum(buckets['past90'] ?? buckets['over90']);

          if (totalDebt == 0) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 64,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không phát sinh nợ phải thu',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          double pct(num v) => totalDebt > 0 ? v / totalDebt * 100 : 0;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total debt card (Glassmorphic)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.03,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Tổng dư nợ phải thu khách hàng',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _fmt(totalDebt),
                        style: GoogleFonts.outfit(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          'Tỷ lệ nợ quá hạn: ${(asNum(summary['overdueRatio']) * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Debt Aging Bar Chart ──
                ChartCard(
                  title: 'Phân nhóm tuổi nợ',
                  height: 200,
                  child: MiniBarChart(
                    values: [
                      current.toDouble(),
                      days30.toDouble(),
                      days60.toDouble(),
                      over90.toDouble(),
                    ],
                    labels: const ['0-30', '31-60', '61-90', '>90'],
                    barColors: const [
                      AppColors.success,
                      AppColors.info,
                      AppColors.warning,
                      AppColors.danger,
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Phân loại theo kỳ hạn nợ',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                _AgingBar(
                  'Chưa đến hạn',
                  current / (totalDebt > 0 ? totalDebt : 1) * 100,
                  _fmt(current),
                  '${pct(current).toStringAsFixed(1)}%',
                  AppColors.success,
                ),
                _AgingBar(
                  'Từ 1 - 30 ngày',
                  days30 / (totalDebt > 0 ? totalDebt : 1) * 100,
                  _fmt(days30),
                  '${pct(days30).toStringAsFixed(1)}%',
                  AppColors.info,
                ),
                _AgingBar(
                  'Từ 31 - 60 ngày',
                  days60 / (totalDebt > 0 ? totalDebt : 1) * 100,
                  _fmt(days60),
                  '${pct(days60).toStringAsFixed(1)}%',
                  AppColors.warning,
                ),
                _AgingBar(
                  'Quá hạn > 60 ngày',
                  over90 / (totalDebt > 0 ? totalDebt : 1) * 100,
                  _fmt(over90),
                  '${pct(over90).toStringAsFixed(1)}%',
                  AppColors.danger,
                ),

                if (customers.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Khách hàng dư nợ cao nhất',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...customers.take(5).map<Widget>((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: c.divider.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['customerName'] ?? '',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: c.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Hạn quá hạn tối đa: ${item['overdueDays'] ?? 0} ngày',
                                  style: TextStyle(
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
                            _fmt(asNum(item['total'])),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 24),
                Text(
                  'Khách hàng nợ quá hạn lâu nhất',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                overdueAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(
                    'Lỗi tải nợ: $e',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  data: (overdueItems) {
                    if (overdueItems.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Không có khách hàng nợ quá hạn',
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                      );
                    }
                    return Column(
                      children: overdueItems.take(10).map<Widget>((item) {
                        final initialChar = (item['customerName'] ?? '?')[0]
                            .toUpperCase();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Elegant Squircle Avatar
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.danger.withValues(
                                      alpha: 0.25,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initialChar,
                                  style: GoogleFonts.outfit(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['customerName'] ?? '',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: c.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_fmt(asNum(item['remaining']))} • ${item['daysOverdue'] ?? 0} ngày quá hạn',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showRemindDialog(
                                  context,
                                  item['customerName'] ?? '',
                                  _fmt(asNum(item['remaining'])),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.send_rounded, size: 12),
                                label: Text(
                                  'Nhắc nợ',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRemindDialog(
    BuildContext context,
    String customerName,
    String debtAmount,
  ) {
    final c = AppThemeColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Gửi tin nhắn nhắc nợ',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Khách hàng: $customerName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Số tiền nợ: $debtAmount',
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chọn phương thức gửi:',
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMethodBtn(context, Icons.sms_rounded, 'SMS', Colors.blue),
                _buildMethodBtn(
                  context,
                  Icons.chat_bubble_rounded,
                  'Zalo',
                  Colors.lightBlue,
                ),
                _buildMethodBtn(
                  context,
                  Icons.alternate_email_rounded,
                  'Email',
                  Colors.redAccent,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Đóng',
              style: TextStyle(
                color: c.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodBtn(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        ToastService.showSuccess(
          'Đã mở ứng dụng $label để gửi tin nhắn nhắc nợ!',
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgingBar extends StatelessWidget {
  final String label, amount, pct;
  final double widthPct;
  final Color color;
  const _AgingBar(this.label, this.widthPct, this.amount, this.pct, this.color);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                pct,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visual glassy progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              color: c.surface,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width:
                      MediaQuery.of(context).size.width *
                      0.8 *
                      (widthPct / 100).clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
