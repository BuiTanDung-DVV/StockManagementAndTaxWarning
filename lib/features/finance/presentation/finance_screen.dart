import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
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
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(cashSummaryProvider((from: _from, to: _to)));
    final txAsync = ref.watch(transactionsProvider((page: 1, type: null, from: _from, to: _to)));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Tài chính & Số cái',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [featureGuideButton(context, 'finance')],
      ),
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: () async {
          ref.invalidate(cashSummaryProvider);
          ref.invalidate(transactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card (Luxury Gradient)
              summaryAsync.when(
                data: (data) {
                  final balance = asDouble(data['balance'] ?? data['currentBalance']);
                  final income = asDouble(data['totalIncome'] ?? data['income']);
                  final expense = asDouble(data['totalExpense'] ?? data['expense']);
                  return Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Số dư quỹ tiền mặt',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8), 
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _currFmt.format(balance),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Thu / Chi panel inside gradient card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                // Income Flow
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF6BE8A0).withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.arrow_downward_rounded, size: 12, color: Color(0xFFA5F3C4)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Tổng thu', 
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.85), 
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500
                                            )
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _currFmt.format(income),
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFA5F3C4),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Elegant vertical divider line
                                Container(width: 1, color: Colors.white.withValues(alpha: 0.2)),
                                
                                // Expense Flow
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF8A80).withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFFFFB4AB)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Tổng chi', 
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.85), 
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500
                                            )
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _currFmt.format(expense),
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFFFB4AB),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => AppShimmer(
                  child: Container(
                    height: 170,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                error: (e, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Lỗi tải sổ quỹ: $e', 
                    style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500)
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Chart 1: Cash Flow Area Chart ──
              summaryAsync.when(
                data: (data) {
                  final dailyFlow = (data['dailyFlow'] as List?) ?? [];
                  if (dailyFlow.isEmpty) {
                    return const EmptyChartPlaceholder(
                      message: 'Chưa có dữ liệu dòng tiền',
                      icon: Icons.show_chart_rounded,
                    );
                  }
                  final incomeData = dailyFlow.map((e) => asDouble(e['income'])).toList();
                  final expenseData = dailyFlow.map((e) => asDouble(e['expense'])).toList();
                  final xLabels = dailyFlow.map((e) {
                    final d = e['date']?.toString() ?? '';
                    if (d.length >= 10) {
                      return '${d.substring(8, 10)}/${d.substring(5, 7)}';
                    }
                    return d;
                  }).toList().cast<String>();
                  return ChartCard(
                    title: 'Dòng tiền tháng này',
                    height: 200,
                    child: MiniAreaChart(
                      data1: incomeData,
                      data2: expenseData,
                      label1: 'Thu',
                      label2: 'Chi',
                      color1: AppColors.success,
                      color2: AppColors.danger,
                      xLabels: xLabels,
                    ),
                  );
                },
                loading: () => AppShimmer(
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),

              // ── Chart 2: Top Expense Categories ──
              Builder(
                builder: (context) {
                  final expCatAsync = ref.watch(expensesByCategoryProvider);
                  return expCatAsync.when(
                    data: (data) {
                      final categories = (data['categories'] as List?) ?? (data['items'] as List?) ?? [];
                      if (categories.isEmpty) {
                        return const EmptyChartPlaceholder(
                          message: 'Chưa có dữ liệu chi phí theo danh mục',
                          icon: Icons.category_rounded,
                        );
                      }
                      const catColors = [
                        AppColors.danger,
                        AppColors.warning,
                        AppColors.info,
                        Colors.purple,
                        Colors.teal,
                      ];
                      final barItems = categories.asMap().entries.map((e) {
                        final cat = e.value;
                        return HBarItem(
                          cat['category']?.toString() ?? cat['name']?.toString() ?? 'Khác',
                          asDouble(cat['total'] ?? cat['amount'] ?? cat['value']),
                          catColors[e.key % catColors.length],
                        );
                      }).toList();
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: c.divider.withValues(alpha: 0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.025),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Top danh mục chi phí',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: c.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            HorizontalBarList(items: barItems),
                          ],
                        ),
                      );
                    },
                    loading: () => AppShimmer(
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Navigation cards section
              Text(
                'Báo cáo & Công cụ tài chính',
                style: GoogleFonts.outfit(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              
              _NavCard('Báo cáo KQKD (Lãi/Lỗ)', HugeIcons.strokeRoundedAnalytics01, () => context.push('/profit-loss')),
              _NavCard('Phân tích Tuổi nợ', HugeIcons.strokeRoundedChartIncrease, () => context.push('/debt-aging')),
              _NavCard('Quản lý Chứng từ', HugeIcons.strokeRoundedInvoice01, () => context.push('/invoices')),
              _NavCard('Bảng kê mua không HĐ', HugeIcons.strokeRoundedInvoice03, () => context.push('/purchases-no-invoice')),
              _NavCard('Dự báo dòng tiền', HugeIcons.strokeRoundedChartIncrease, () => context.push('/cashflow-forecast')),
              _NavCard('Chốt sổ cuối ngày', HugeIcons.strokeRoundedCheckmarkCircle02, () => context.push('/daily-closing')),
              _NavCard('Tính thuế HKD', HugeIcons.strokeRoundedCalculator01, () => context.push('/tax-calculator')),
              _NavCard('Sổ chi phí SXKD', HugeIcons.strokeRoundedCoinsDollar, () => context.push('/expense-ledger')),
              _NavCard('Theo dõi nghĩa vụ thuế', HugeIcons.strokeRoundedFlag01, () => context.push('/tax-obligations')),
              _NavCard('Sổ lương nhân viên', HugeIcons.strokeRoundedUserMultiple, () => context.push('/salary-ledger')),
              _NavCard('Ước Tính & Xuất Thuế HTKK', HugeIcons.strokeRoundedCalculator01, () => context.push('/tax-estimate')),
              _NavCard('Kê khai thuế', HugeIcons.strokeRoundedInvoice01, () => context.push('/tax-declaration')),
              
              const SizedBox(height: 24),

              // Recent transactions section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Giao dịch gần đây', 
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/transactions'), 
                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                    label: const Text('Xem tất cả', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              txAsync.when(
                data: (data) {
                  final items = (data['items'] as List?) ?? [];
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Chưa phát sinh giao dịch nào hôm nay',
                          style: TextStyle(fontSize: 13, color: c.textMuted),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: items.take(5).map((tx) {
                      final isIncome = tx['type'] == 'INCOME' || tx['type'] == 'income';
                      final amount = asDouble(tx['amount']);
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.01),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isIncome ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                size: 18,
                                color: isIncome ? AppColors.success : AppColors.danger,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx['description'] ?? tx['note'] ?? (isIncome ? 'Giao dịch thu' : 'Giao dịch chi'),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis, // Prevention of text overflow
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tx['paymentMethod']?.toString() ?? 'Tiền mặt',
                                    style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${isIncome ? '+' : '-'}${_currFmt.format(amount)}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: isIncome ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const ShimmerList(count: 3),
                error: (e, s) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Navigation Card
class _NavCard extends StatelessWidget {
  final String title;
  final dynamic icon;
  final VoidCallback onTap;
  const _NavCard(this.title, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: c.divider.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: HugeIcon(icon: icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title, 
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, 
                  fontSize: 13,
                  color: c.textPrimary,
                )
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, color: c.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}
