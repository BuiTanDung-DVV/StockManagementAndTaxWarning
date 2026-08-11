import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/custom_date_range_picker.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/utils/type_parser.dart';
import '../providers/finance_provider.dart';

class ProfitLossScreen extends ConsumerStatefulWidget {
  const ProfitLossScreen({super.key});
  @override
  ConsumerState<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends ConsumerState<ProfitLossScreen> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
  }

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  Future<void> _pickDateRange() async {
    final picked = await showCustomDateRangePicker(
      context,
      initialRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final from = _range.start.toIso8601String().split('T').first;
    final to = _range.end.toIso8601String().split('T').first;
    final plAsync = ref.watch(profitLossProvider((from: from, to: to)));
    final label =
        '${DateFormat('dd/MM').format(_range.start)} - ${DateFormat('dd/MM').format(_range.end)}';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Báo cáo Kết quả Kinh doanh',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range_rounded, size: 16),
            label: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          featureGuideButton(context, 'profit_loss'),
        ],
      ),
      body: plAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Lỗi: $e', style: TextStyle(color: AppColors.danger)),
        ),
        data: (data) {
          final revenue = TypeParser.asDouble(data['revenue']);
          final cogs = TypeParser.asDouble(data['cogs']);
          final grossProfit = TypeParser.asDouble(data['grossProfit']);
          final expenses = TypeParser.asDouble(data['expenses']);
          final netProfit = TypeParser.asDouble(data['netProfit']);
          final grossPct = revenue > 0
              ? (grossProfit / revenue * 100).toStringAsFixed(1)
              : '0.0';
          final netPct = revenue > 0
              ? (netProfit / revenue * 100).toStringAsFixed(1)
              : '0.0';

          final cogsPct = revenue > 0
              ? (cogs / revenue * 100).toStringAsFixed(1)
              : '0.0';
          final expensesPct = revenue > 0
              ? (expenses / revenue * 100).toStringAsFixed(1)
              : '0.0';

          if (revenue == 0 && cogs == 0 && expenses == 0) {
            return const AppEmpty(
              visual: AppEmptyVisual.finance,
              message: 'Chưa có dữ liệu giao dịch phát sinh',
              subtitle: 'Thêm giao dịch thu/chi để xem báo cáo KQKD',
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active range badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Kỳ đối chiếu: $from → $to',
                        style: GoogleFonts.manrope(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _ProfitBridge(
                  revenue: revenue,
                  cogs: cogs,
                  grossProfit: grossProfit,
                  expenses: expenses,
                  netProfit: netProfit,
                  formatter: _fmt,
                ),
                const SizedBox(height: 20),
                AppFillGrid(
                  minItemWidth: 205,
                  maxColumns: 3,
                  itemHeight: 94,
                  children: [
                    AppKpiCard(
                      title: 'Doanh thu',
                      value: _fmt(revenue),
                      color: theme.colorScheme.primary,
                      assetPath: AppAssets.revenue,
                      badgeText: 'Kỳ đã chọn',
                    ),
                    AppKpiCard(
                      title: 'Giá vốn hàng bán',
                      value: _fmt(cogs),
                      color: AppColors.danger,
                      assetPath: AppAssets.inventory,
                      badgeText: '$cogsPct% doanh thu',
                    ),
                    AppKpiCard(
                      title: 'Lợi nhuận gộp',
                      value: _fmt(grossProfit),
                      color: grossProfit >= 0
                          ? AppColors.success
                          : AppColors.danger,
                      assetPath: AppAssets.profit,
                      badgeText: '$grossPct% doanh thu',
                    ),
                    AppKpiCard(
                      title: 'Chi phí vận hành',
                      value: _fmt(expenses),
                      color: AppColors.warning,
                      assetPath: AppAssets.cash,
                      badgeText: '$expensesPct% doanh thu',
                    ),
                    AppKpiCard(
                      title: netProfit >= 0 ? 'Lợi nhuận ròng' : 'Lỗ ròng',
                      value: _fmt(netProfit),
                      color: netProfit >= 0
                          ? AppColors.success
                          : AppColors.danger,
                      assetPath: AppAssets.profit,
                      badgeText: '$netPct% doanh thu',
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfitBridge extends StatelessWidget {
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final String Function(num value) formatter;

  const _ProfitBridge({
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final rows = [
      (label: 'Doanh thu', value: revenue, color: AppColors.primary),
      (label: 'Trừ giá vốn', value: -cogs, color: AppColors.danger),
      (
        label: 'Bằng lợi nhuận gộp',
        value: grossProfit,
        color: grossProfit >= 0 ? AppColors.success : AppColors.danger,
      ),
      (
        label: 'Trừ chi phí vận hành',
        value: -expenses,
        color: AppColors.warning,
      ),
      (
        label: netProfit >= 0 ? 'Bằng lợi nhuận ròng' : 'Bằng lỗ ròng',
        value: netProfit,
        color: netProfit >= 0 ? AppColors.success : AppColors.danger,
      ),
    ];
    final scale = rows.fold<double>(1, (maximum, row) {
      final absolute = row.value.abs();
      return absolute > maximum ? absolute : maximum;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.divider),
        boxShadow: const [AppTheme.diffusionShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cầu nối lợi nhuận',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Doanh thu − giá vốn = lợi nhuận gộp; lợi nhuận gộp − chi phí vận hành = lợi nhuận ròng.',
            style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < rows.length; index++) ...[
            _ProfitBridgeRow(
              label: rows[index].label,
              value: rows[index].value,
              scale: scale,
              color: rows[index].color,
              formatter: formatter,
              emphasized: index == 2 || index == 4,
            ),
            if (index < rows.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ProfitBridgeRow extends StatelessWidget {
  final String label;
  final double value;
  final double scale;
  final Color color;
  final String Function(num value) formatter;
  final bool emphasized;

  const _ProfitBridgeRow({
    required this.label,
    required this.value,
    required this.scale,
    required this.color,
    required this.formatter,
    required this.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final ratio = scale <= 0 ? 0.0 : (value.abs() / scale).clamp(0.0, 1.0);
    return Semantics(
      label: '$label: ${formatter(value)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                    color: emphasized ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatter(value),
                style: AppTheme.tabularStyle(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: emphasized ? 9 : 7,
              backgroundColor: c.divider.withValues(alpha: 0.5),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
