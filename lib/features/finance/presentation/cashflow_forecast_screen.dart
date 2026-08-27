import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
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
    final compactLayout = MediaQuery.sizeOf(context).width < 720;

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
          'Dự Báo Dòng Tiền',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'cashflow_forecast'),
          if (compactLayout)
            AppPrimaryHeaderAction(
              label: 'Thêm mới',
              assetPath: AppAssets.add,
              heroTag: 'cashflow-add-compact',
              onPressed: () => _showCreateMenu(context, ref),
            ),
          const SizedBox(width: 8),
        ],
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
                  visual: AppEmptyVisual.finance,
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
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                      ),

                      Container(
                        height: MediaQuery.sizeOf(context).width < 600
                            ? 300
                            : 330,
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
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Dòng tiền thuần dự kiến',
                                          style: GoogleFonts.manrope(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: c.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Thu dự kiến − chi dự kiến theo ngày',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: c.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Đơn vị: đồng',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: c.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
                                        reservedSize: 86,
                                        getTitlesWidget: (value, meta) {
                                          if (value == meta.max ||
                                              value == meta.min) {
                                            return const SizedBox.shrink();
                                          }
                                          return Text(
                                            compactVietnameseCurrency(value),
                                            style: AppTheme.tabularStyle(
                                              context,
                                              color: c.textMuted,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
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
                                              idx >= forecasts.length) {
                                            return const SizedBox.shrink();
                                          }
                                          final f = forecasts[idx];
                                          final dateStr =
                                              f['forecastDate']
                                                  ?.toString()
                                                  .split('T')
                                                  .first ??
                                              '';
                                          if (dateStr.length < 5) {
                                            return const SizedBox.shrink();
                                          }
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
                                          final dateStr =
                                              f['forecastDate']
                                                  ?.toString()
                                                  .split('T')
                                                  .first ??
                                              '';
                                          return LineTooltipItem(
                                            '$dateStr\n${_fmt(balance)}',
                                            GoogleFonts.manrope(
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
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Thuần dự kiến',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: c.textMuted,
                                            ),
                                          ),
                                          Text(
                                            _fmt(balance),
                                            style: GoogleFonts.manrope(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: isPositive
                                                  ? AppColors.success
                                                  : AppColors.danger,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
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
                          style: GoogleFonts.manrope(
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
                        final startDate = DateTime.tryParse(
                          b['startDate']?.toString() ?? '',
                        );
                        final endDate = DateTime.tryParse(
                          b['endDate']?.toString() ?? '',
                        );
                        final dateRange = startDate != null && endDate != null
                            ? '${DateFormat('dd/MM/yyyy').format(startDate)} – ${DateFormat('dd/MM/yyyy').format(endDate)}'
                            : 'Chưa xác định khoảng thời gian';

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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b['name'] ?? '',
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: c.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dateRange,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: c.textSecondary,
                                          ),
                                        ),
                                      ],
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

                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  height: 8,
                                  color: c.surface,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: pct.clamp(0, 1).toDouble(),
                                      heightFactor: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
      floatingActionButton: compactLayout
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCreateMenu(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Thêm mới',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
              ),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
    );
  }

  void _showCreateMenu(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.card,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Dự báo dòng tiền'),
                subtitle: const Text('Ghi khoản thu và chi dự kiến theo ngày'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddForecastDialog(context, ref);
                },
              ),
              ListTile(
                title: const Text('Kế hoạch ngân sách'),
                subtitle: const Text(
                  'Đặt mục tiêu thu, hạn mức chi và khoảng theo dõi',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddBudgetDialog(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context, WidgetRef ref) {
    final nameC = TextEditingController();
    final incomeC = TextEditingController();
    final expenseC = TextEditingController();
    var startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    var endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Thêm kế hoạch ngân sách',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(
                    labelText: 'Tên kế hoạch',
                    hintText: 'Ví dụ: Ngân sách tháng 8',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BudgetDateField(
                        label: 'Từ ngày',
                        value: startDate,
                        onTap: () async {
                          final value = await showDatePicker(
                            context: dialogContext,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (value != null) {
                            setDialogState(() => startDate = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BudgetDateField(
                        label: 'Đến ngày',
                        value: endDate,
                        onTap: () async {
                          final value = await showDatePicker(
                            context: dialogContext,
                            initialDate: endDate,
                            firstDate: startDate,
                            lastDate: DateTime(2100),
                          );
                          if (value != null) {
                            setDialogState(() => endDate = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: incomeC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mục tiêu thu (đồng)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expenseC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hạn mức chi (đồng)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameC.text.trim();
                final plannedIncome = double.tryParse(incomeC.text);
                final plannedExpense = double.tryParse(expenseC.text);
                if (name.isEmpty ||
                    plannedIncome == null ||
                    plannedIncome < 0 ||
                    plannedExpense == null ||
                    plannedExpense < 0 ||
                    startDate.isAfter(endDate)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng kiểm tra tên, ngày và số tiền'),
                    ),
                  );
                  return;
                }
                try {
                  await ref.read(financeRepoProvider).createBudgetPlan({
                    'name': name,
                    'period': 'CUSTOM',
                    'startDate': startDate.toIso8601String().split('T').first,
                    'endDate': endDate.toIso8601String().split('T').first,
                    'plannedIncome': plannedIncome,
                    'plannedExpense': plannedExpense,
                  });
                  ref.invalidate(budgetPlansProvider);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Không thể lưu: $error')),
                    );
                  }
                }
              },
              child: const Text('Lưu kế hoạch'),
            ),
          ],
        ),
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
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
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
                    style: GoogleFonts.manrope(
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

class _BudgetDateField extends StatelessWidget {
  const _BudgetDateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(DateFormat('dd/MM/yyyy').format(value)),
      ),
    );
  }
}
