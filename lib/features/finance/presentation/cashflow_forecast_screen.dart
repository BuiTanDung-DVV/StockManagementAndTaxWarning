import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../providers/finance_provider.dart';

class CashflowForecastScreen extends ConsumerWidget {
  const CashflowForecastScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final forecastAsync = ref.watch(forecastsProvider);
    final budgetAsync = ref.watch(budgetPlansProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Dự Báo Dòng Tiền',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [featureGuideButton(context, 'cashflow_forecast')],
      ),
      body: forecastAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Lỗi: $e', style: TextStyle(color: AppColors.danger)),
        ),
        data: (forecasts) {
          return budgetAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Lỗi: $e', style: TextStyle(color: AppColors.danger)),
            ),
            data: (budgets) {
              if (forecasts.isEmpty && budgets.isEmpty) {
                return AppEmpty(
                  message: 'Chưa có dữ liệu dự báo',
                  action: ElevatedButton.icon(
                    icon: const Icon(Icons.trending_up_rounded),
                    label: const Text('Thêm dự báo ngay'),
                    onPressed: () => _showAddForecastDialog(context, ref),
                  ),
                );
              }
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (forecasts.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Dự báo theo ngày',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                      ),

                      // Beautiful trend chart
                      Container(
                        height: 180,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.only(
                          left: 10,
                          right: 16,
                          top: 18,
                          bottom: 8,
                        ),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: c.divider.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 6,
                                bottom: 12,
                              ),
                              child: Text(
                                'Xu hướng biến động dòng tiền',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: c.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) => FlLine(
                                      color: c.divider.withValues(alpha: 0.3),
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 42,
                                        getTitlesWidget: (value, meta) {
                                          if (value == meta.max ||
                                              value == meta.min)
                                            return const SizedBox.shrink();
                                          final isNeg = value < 0;
                                          final absVal = value.abs();
                                          String label = '';
                                          if (absVal >= 1000000) {
                                            label =
                                                '${isNeg ? '-' : ''}${(absVal / 1000000).toStringAsFixed(0)}Tr';
                                          } else if (absVal >= 1000) {
                                            label =
                                                '${isNeg ? '-' : ''}${(absVal / 1000).toStringAsFixed(0)}K';
                                          } else {
                                            label =
                                                '${isNeg ? '-' : ''}${absVal.toStringAsFixed(0)}';
                                          }
                                          return Text(
                                            label,
                                            style: TextStyle(
                                              color: c.textMuted,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.right,
                                          );
                                        },
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 22,
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.toInt();
                                          if (idx < 0 ||
                                              idx >= forecasts.length)
                                            return const SizedBox.shrink();
                                          final f = forecasts[idx];
                                          final dateStr =
                                              f['forecastDate']
                                                  ?.toString()
                                                  .split('T')
                                                  .first ??
                                              '';
                                          if (dateStr.length < 5)
                                            return const SizedBox.shrink();
                                          final parts = dateStr.split('-');
                                          final displayDate = parts.length >= 3
                                              ? '${parts[2]}/${parts[1]}'
                                              : dateStr;

                                          if (forecasts.length > 5 &&
                                              idx %
                                                      (forecasts.length / 4)
                                                          .ceil() !=
                                                  0 &&
                                              idx != forecasts.length - 1) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              displayDate,
                                              style: TextStyle(
                                                color: c.textMuted,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineTouchData: LineTouchData(
                                    touchTooltipData: LineTouchTooltipData(
                                      getTooltipColor: (touchedSpot) =>
                                          c.surface,
                                      getTooltipItems: (touchedSpots) {
                                        return touchedSpots.map((spot) {
                                          final f = forecasts[spot.x.toInt()];
                                          final balance = spot.y;
                                          final formatted =
                                              NumberFormat.compact(
                                                locale: 'vi_VN',
                                              ).format(balance);
                                          final dateStr =
                                              f['forecastDate']
                                                  ?.toString()
                                                  .split('T')
                                                  .first ??
                                              '';
                                          return LineTooltipItem(
                                            '$dateStr\n$formatted',
                                            GoogleFonts.outfit(
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          );
                                        }).toList();
                                      },
                                    ),
                                  ),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: forecasts.asMap().entries.map((
                                        entry,
                                      ) {
                                        final idx = entry.key.toDouble();
                                        final f = entry.value;
                                        final income =
                                            num.tryParse(
                                              f['expectedIncome']?.toString() ??
                                                  '0',
                                            ) ??
                                            0;
                                        final expense =
                                            num.tryParse(
                                              f['expectedExpense']
                                                      ?.toString() ??
                                                  '0',
                                            ) ??
                                            0;
                                        final balance =
                                            num.tryParse(
                                              f['expectedBalance']
                                                      ?.toString() ??
                                                  '0',
                                            ) ??
                                            (income - expense);
                                        return FlSpot(idx, balance.toDouble());
                                      }).toList(),
                                      isCurved: true,
                                      color: theme.colorScheme.primary,
                                      barWidth: 3.5,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        gradient: LinearGradient(
                                          colors: [
                                            theme.colorScheme.primary
                                                .withValues(alpha: 0.15),
                                            theme.colorScheme.primary
                                                .withValues(alpha: 0.0),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      ...forecasts.map<Widget>((f) {
                        final income =
                            num.tryParse(
                              f['expectedIncome']?.toString() ?? '0',
                            ) ??
                            0;
                        final expense =
                            num.tryParse(
                              f['expectedExpense']?.toString() ?? '0',
                            ) ??
                            0;
                        final balance =
                            num.tryParse(
                              f['expectedBalance']?.toString() ?? '0',
                            ) ??
                            (income - expense);
                        final isPositive = balance >= 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: c.divider.withValues(alpha: 0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: isPositive
                                        ? AppColors.success
                                        : AppColors.danger,
                                    width: 5,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 14,
                                            color: c.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            f['forecastDate']
                                                    ?.toString()
                                                    .split('T')
                                                    .first ??
                                                '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _fmt(balance),
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: isPositive
                                              ? AppColors.success
                                              : AppColors.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: Text(
                                          'Thu: ${_fmt(income)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.success,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: Text(
                                          'Chi: ${_fmt(expense)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.danger,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                    if (budgets.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Kế hoạch & Ngân sách',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      ...budgets.map<Widget>((b) {
                        final plannedIncome =
                            num.tryParse(
                              b['plannedIncome']?.toString() ?? '0',
                            ) ??
                            0;
                        final actualIncome =
                            num.tryParse(
                              b['actualIncome']?.toString() ?? '0',
                            ) ??
                            0;
                        final plannedExpense =
                            num.tryParse(
                              b['plannedExpense']?.toString() ?? '0',
                            ) ??
                            0;
                        final actualExpense =
                            num.tryParse(
                              b['actualExpense']?.toString() ?? '0',
                            ) ??
                            0;
                        final pct = plannedIncome > 0
                            ? (actualIncome / plannedIncome)
                            : 0.0;
                        final isFullyAchieved = actualIncome >= plannedIncome;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: c.divider.withValues(alpha: 0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.pie_chart_outline_rounded,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      b['name'] ?? '',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: c.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Kế hoạch thu: ${_fmt(plannedIncome)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Thực tế: ${_fmt(actualIncome)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isFullyAchieved
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Rounded visual budget progress track
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  height: 8,
                                  color: c.surface,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      width:
                                          MediaQuery.of(context).size.width *
                                          0.8 *
                                          pct.clamp(0, 1).toDouble(),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: LinearGradient(
                                          colors: [
                                            theme.colorScheme.primary,
                                            isFullyAchieved
                                                ? AppColors.success
                                                : theme.colorScheme.primary
                                                      .withValues(alpha: 0.7),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Kế hoạch chi: ${_fmt(plannedExpense)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Thực tế chi: ${_fmt(actualExpense)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: actualExpense <= plannedExpense
                                          ? AppColors.success
                                          : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddForecastDialog(context, ref),
        icon: const Icon(Icons.trending_up_rounded),
        label: Text(
          'Thêm dự báo',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddForecastDialog(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final incomeC = TextEditingController();
    final expenseC = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Thêm dự báo dòng tiền',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: Icon(
                    Icons.calendar_month_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    DateFormat('dd/MM/yyyy').format(selectedDate),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  trailing: const Icon(Icons.edit_rounded, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) {
                      setDialogState(() => selectedDate = d);
                    }
                  },
                ),
              ),
              TextField(
                controller: incomeC,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Thu dự kiến (VNĐ)',
                  prefixIcon: const Icon(
                    Icons.arrow_downward_rounded,
                    color: AppColors.success,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: c.divider.withValues(alpha: 0.6),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expenseC,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Chi dự kiến (VNĐ)',
                  prefixIcon: const Icon(
                    Icons.arrow_upward_rounded,
                    color: AppColors.danger,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: c.divider.withValues(alpha: 0.6),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Hủy', style: TextStyle(color: c.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final income = double.tryParse(incomeC.text) ?? 0;
                final expense = double.tryParse(expenseC.text) ?? 0;
                try {
                  await ref.read(financeRepoProvider).createForecast({
                    'forecastDate': selectedDate
                        .toIso8601String()
                        .split('T')
                        .first,
                    'expectedIncome': income,
                    'expectedExpense': expense,
                    'expectedBalance': income - expense,
                  });
                  ref.invalidate(forecastsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi: $e'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text('Lưu dự báo'),
            ),
          ],
        ),
      ),
    );
  }
}
