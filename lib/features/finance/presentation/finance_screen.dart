import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
final _today = DateTime.now();
final _from = DateTime(_today.year, _today.month, 1).toIso8601String().split('T')[0];
final _to = _today.toIso8601String().split('T')[0];

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final summaryAsync = ref.watch(cashSummaryProvider((from: _from, to: _to)));
    final txAsync = ref.watch(transactionsProvider((page: 1, type: null, from: _from, to: _to)));

    return Scaffold(
      appBar: AppBar(
        title: Text('Tài chính'),
        actions: [featureGuideButton(context, 'finance')],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cashSummaryProvider);
          ref.invalidate(transactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Balance Card ──
              summaryAsync.when(
                data: (data) {
                  final balance = (data['balance'] ?? data['currentBalance'] ?? 0).toDouble();
                  final income = (data['totalIncome'] ?? data['income'] ?? 0).toDouble();
                  final expense = (data['totalExpense'] ?? data['expense'] ?? 0).toDouble();
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      Text(
                        'Số dư quỹ tiền mặt',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _currFmt.format(balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Thu / Chi panel
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IntrinsicHeight(
                          child: Row(children: [
                            // Thu
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6BE8A0).withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.arrow_downward, size: 12, color: Color(0xFFA5F3C4)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('Thu', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _currFmt.format(income),
                                      style: const TextStyle(
                                        color: Color(0xFFA5F3C4),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Divider
                            Container(width: 1, color: Colors.white24),
                            // Chi
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF8A80).withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.arrow_upward, size: 12, color: Color(0xFFFFB4AB)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('Chi', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _currFmt.format(expense),
                                      style: const TextStyle(
                                        color: Color(0xFFFFB4AB),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  );
                },
                loading: () => AppShimmer(
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                error: (e, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Lỗi: $e', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 20),

              // ── Navigation cards ──
              Text(
                'Báo cáo & Công cụ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _NavCard('Báo cáo KQKD (Lãi/Lỗ)', HugeIcons.strokeRoundedAnalytics01, () => context.push('/profit-loss')),
              _NavCard('Phân tích Tuổi nợ', HugeIcons.strokeRoundedChartIncrease, () => context.push('/debt-aging')),
              _NavCard('Quản lý Hóa đơn', HugeIcons.strokeRoundedInvoice01, () => context.push('/invoices')),
              _NavCard('Bảng kê mua không HĐ', HugeIcons.strokeRoundedInvoice03, () => context.push('/purchases-no-invoice')),
              _NavCard('Dự báo dòng tiền', HugeIcons.strokeRoundedChartIncrease, () => context.push('/cashflow-forecast')),
              _NavCard('Chốt sổ cuối ngày', HugeIcons.strokeRoundedCheckmarkCircle02, () => context.push('/daily-closing')),
              _NavCard('Tính thuế HKD', HugeIcons.strokeRoundedCalculator01, () => context.push('/tax-calculator')),
              _NavCard('Sổ chi phí SXKD', HugeIcons.strokeRoundedCoinsDollar, () => context.push('/expense-ledger')),
              _NavCard('Theo dõi nghĩa vụ thuế', HugeIcons.strokeRoundedFlag01, () => context.push('/tax-obligations')),
              _NavCard('Sổ lương nhân viên', HugeIcons.strokeRoundedUserMultiple, () => context.push('/salary-ledger')),
              _NavCard('Kê khai thuế', HugeIcons.strokeRoundedInvoice01, () => context.push('/tax-declaration')),
              const SizedBox(height: 20),

              // ── Recent transactions ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Giao dịch gần đây', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  TextButton(onPressed: () => context.push('/transactions'), child: Text('Xem tất cả')),
                ],
              ),
              txAsync.when(
                data: (data) {
                  final items = (data['items'] as List?) ?? [];
                  return Column(
                    children: items.take(5).map((tx) {
                      final isIncome = tx['type'] == 'INCOME' || tx['type'] == 'income';
                      final amount = (tx['amount'] ?? 0).toDouble();
                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isIncome ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              size: 18,
                              color: isIncome ? AppColors.success : AppColors.danger,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx['description'] ?? tx['note'] ?? (isIncome ? 'Thu' : 'Chi'),
                                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                ),
                                Text(
                                  tx['paymentMethod'] ?? '',
                                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isIncome ? '+' : '-'}${_currFmt.format(amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isIncome ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ]),
                      );
                    }).toList(),
                  );
                },
                loading: () => const ShimmerList(count: 3),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Navigation Card ──
class _NavCard extends StatelessWidget {
  final String title;
  final dynamic icon;
  final VoidCallback onTap;
  const _NavCard(this.title, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(icon: icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: c.textMuted, size: 18),
        ]),
      ),
    );
  }
}
