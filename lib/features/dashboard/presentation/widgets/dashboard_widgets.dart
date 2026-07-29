import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/chart_widgets.dart';
import '../../../../core/utils/excel_export_service.dart';
import '../../../finance/providers/finance_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../settings/providers/shop_provider.dart';
import '../../../settings/providers/tax_config_provider.dart';
import '../../../sales/providers/sales_provider.dart';
import '../../../inventory/providers/inventory_provider.dart';
import '../../../customers/providers/customer_provider.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class TaxObligationReminder extends ConsumerWidget {
  const TaxObligationReminder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final taxAsync = ref.watch(taxObligationsProvider);

    return taxAsync.when(
      loading: () => const SizedBox(height: 8),
      error: (_, _) => AppInlineError(
        message: 'Không thể tải nghĩa vụ thuế.',
        onRetry: () => ref.invalidate(taxObligationsProvider),
      ),
      data: (data) {
        final all = ((data['items'] as List?) ?? []);
        final pending = all.where((t) => t['status'] != 'done').toList();
        if (pending.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            children: pending.map<Widget>((t) {
              final period = t['period'] ?? '';
              final dueDateStr = t['dueDate']?.toString().split('T').first;
              final vatDeclared =
                  num.tryParse(t['vatDeclared']?.toString() ?? '0') ?? 0;
              final vatPaid =
                  num.tryParse(t['vatPaid']?.toString() ?? '0') ?? 0;
              final pitDeclared =
                  num.tryParse(t['pitDeclared']?.toString() ?? '0') ?? 0;
              final pitPaid =
                  num.tryParse(t['pitPaid']?.toString() ?? '0') ?? 0;
              final vatOwed = vatDeclared - vatPaid;
              final pitOwed = pitDeclared - pitPaid;
              final rawTotalOwed = vatOwed + pitOwed;
              final totalOwed = rawTotalOwed < 0 ? 0.0 : rawTotalOwed;
              final status = t['status'] ?? 'pending';

              // Calculate days remaining
              int? daysLeft;
              if (dueDateStr != null) {
                final dueDate = DateTime.tryParse(dueDateStr);
                if (dueDate != null) {
                  daysLeft = dueDate.difference(DateTime.now()).inDays;
                }
              }

              // Urgency color + label
              Color urgencyColor;
              String urgencyLabel;
              IconData urgencyIcon;
              if (status == 'overdue' || (daysLeft != null && daysLeft < 0)) {
                urgencyColor = AppColors.danger;
                urgencyLabel =
                    'Quá hạn${daysLeft != null ? " ${(-daysLeft)} ngày" : ""}';
                urgencyIcon = Icons.error_rounded;
              } else if (daysLeft != null && daysLeft <= 7) {
                urgencyColor = AppColors.danger;
                urgencyLabel = 'Còn $daysLeft ngày';
                urgencyIcon = Icons.warning_rounded;
              } else if (daysLeft != null && daysLeft <= 30) {
                urgencyColor = AppColors.warning;
                urgencyLabel = 'Còn $daysLeft ngày';
                urgencyIcon = Icons.schedule_rounded;
              } else {
                urgencyColor = AppColors.info;
                urgencyLabel = daysLeft != null
                    ? 'Còn $daysLeft ngày'
                    : 'Chờ nộp';
                urgencyIcon = Icons.info_outline_rounded;
              }

              return GestureDetector(
                onTap: () => context.push('/tax-obligations'),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: urgencyColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(urgencyIcon, size: 22, color: urgencyColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thuế $period',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Còn phải nộp: ${_currFmt.format(totalOwed)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (dueDateStr != null)
                              Text(
                                'Hạn: $dueDateStr',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          urgencyLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: urgencyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ); // closes GestureDetector
            }).toList(),
          ),
        );
      },
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title, value;
  final dynamic icon;
  final Color color;
  final bool isHero;
  final String? assetPath;
  final String? badgeText;

  const SummaryCard(
    this.title,
    this.value,
    this.icon,
    this.color, {
    super.key,
    this.isHero = false,
    this.assetPath,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final textColor = c.textPrimary;
    final subTextColor = c.textSecondary;
    final iconBg = color.withValues(alpha: 0.12);
    final iconColor = color;

    Widget iconWidget;
    if (assetPath != null && assetPath!.endsWith('.svg')) {
      iconWidget = SvgPicture.asset(
        assetPath!,
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    } else if (icon is IconData) {
      iconWidget = Icon(icon as IconData, size: 18, color: iconColor);
    } else {
      iconWidget = HugeIcon(icon: icon, size: 18, color: iconColor);
    }

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        child: iconWidget,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: subTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeText != null && badgeText!.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      badgeText!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  const QuickAction(this.icon, this.label, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(100),
      ),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(100),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: theme.colorScheme.primary.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: c.divider.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: icon,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TimeFilterBar extends StatelessWidget {
  final String currentFilter;
  final Function(String) onChanged;
  const TimeFilterBar(this.currentFilter, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.cardAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.divider),
      ),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          _buildBtn(context, 'week', 'Tuần này', theme, c),
          _buildBtn(context, 'month', 'Tháng này', theme, c),
          _buildBtn(context, '6_months', '6 tháng', theme, c),
          _buildBtn(context, 'year', 'Năm nay', theme, c),
        ],
      ),
    );
  }

  Widget _buildBtn(
    BuildContext context,
    String val,
    String label,
    ThemeData theme,
    AppThemeColors c,
  ) {
    final active = currentFilter == val;
    return GestureDetector(
      onTap: () => onChanged(val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.card : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? c.textPrimary : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class ComparisonBarChart extends StatefulWidget {
  final List<dynamic> currentData;
  final List<dynamic> previousData;
  final String label1, label2;
  final Widget? filterWidget;
  const ComparisonBarChart(
    this.currentData,
    this.previousData,
    this.label1,
    this.label2, {
    this.filterWidget,
    super.key,
  });

  @override
  State<ComparisonBarChart> createState() => _ComparisonBarChartState();
}

class _ComparisonBarChartState extends State<ComparisonBarChart> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void didUpdateWidget(covariant ComparisonBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final periodChanged =
        oldWidget.label1 != widget.label1 ||
        oldWidget.label2 != widget.label2 ||
        oldWidget.currentData.length != widget.currentData.length ||
        oldWidget.previousData.length != widget.previousData.length;
    if (periodChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_horizontalController.hasClients) {
          _horizontalController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final currentData = widget.currentData;
    final previousData = widget.previousData;
    final label1 = widget.label1;
    final label2 = widget.label2;
    final filterWidget = widget.filterWidget;

    if (currentData.isEmpty && previousData.isEmpty) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.divider),
        ),
        child: const AppEmpty(
          visual: AppEmptyVisual.finance,
          message: 'Chưa có dữ liệu giao dịch',
          subtitle: 'Biểu đồ sẽ xuất hiện khi có dữ liệu trong kỳ.',
        ),
      );
    }

    final maxLen = currentData.length > previousData.length
        ? currentData.length
        : previousData.length;
    double maxRev = 0;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Create grouped data
    final barGroups = <BarChartGroupData>[];
    double barWidth;
    double bSpace;
    if (maxLen <= 7) {
      barWidth = isMobile ? 14.0 : 20.0;
      bSpace = isMobile ? 8.0 : 12.0;
    } else {
      barWidth = isMobile ? 11.0 : 16.0;
      bSpace = isMobile ? 6.0 : 8.0;
    }

    final pastColor = Colors.grey.shade400;
    final presentColor = theme.colorScheme.primary;

    for (int i = 0; i < maxLen; i++) {
      double rev1 = 0;
      double rev2 = 0;
      if (i < currentData.length) {
        rev1 =
            num.tryParse(
              currentData[i]['revenue']?.toString() ?? '0',
            )?.toDouble() ??
            0.0;
        if (rev1 > maxRev) maxRev = rev1;
      }
      if (i < previousData.length) {
        rev2 =
            num.tryParse(
              previousData[i]['revenue']?.toString() ?? '0',
            )?.toDouble() ??
            0.0;
        if (rev2 > maxRev) maxRev = rev2;
      }

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rev2,
              color: pastColor,
              width: barWidth,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: rev1,
              color: presentColor,
              width: barWidth,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
          barsSpace: bSpace,
        ),
      );
    }

    if (maxRev == 0) maxRev = 1000000;

    return Container(
      height: isMobile ? 390 : 440,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 16,
        14,
        isMobile ? 12 : 16,
        12,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Doanh thu theo kỳ',
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                    Text(
                      'Đơn vị: đồng',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
                if (filterWidget != null) ...[
                  const SizedBox(height: 10),
                  filterWidget,
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _buildLegendItem(label2, pastColor, c.textSecondary),
                    _buildLegendItem(label1, presentColor, c.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double minWidth =
                    barGroups.length * (isMobile ? 58.0 : 66.0);
                final canScroll = minWidth > constraints.maxWidth;
                return Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: canScroll,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Container(
                      padding: const EdgeInsets.only(right: 16, bottom: 10),
                      width: canScroll ? minWidth : constraints.maxWidth,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxRev * 1.18,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (v) => FlLine(
                              color: c.divider.withValues(alpha: 0.45),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border(
                              bottom: BorderSide(
                                color: c.divider.withValues(alpha: 0.5),
                                width: 1,
                              ),
                              left: BorderSide.none,
                              right: BorderSide.none,
                              top: BorderSide.none,
                            ),
                          ),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              getTooltipColor: (group) => const Color(
                                0xFF1E293B,
                              ).withValues(alpha: 0.9),
                              tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              tooltipMargin: 8,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                    final val = NumberFormat.decimalPattern(
                                      'vi_VN',
                                    ).format(rod.toY.round());
                                    final idx = group.x;
                                    String dateStr = '';
                                    if (rodIndex == 0 &&
                                        idx < previousData.length) {
                                      dateStr =
                                          previousData[idx]['date']
                                              as String? ??
                                          '';
                                    } else if (rodIndex == 1 &&
                                        idx < currentData.length) {
                                      dateStr =
                                          currentData[idx]['date'] as String? ??
                                          '';
                                    }

                                    final parts = dateStr.split('-');
                                    String displayDate = dateStr;
                                    if (parts.length >= 3) {
                                      displayDate =
                                          '${parts[2]}/${parts[1]}/${parts[0]}';
                                    } else if (parts.length == 2) {
                                      displayDate = '${parts[1]}/${parts[0]}';
                                    }

                                    final dateLine = displayDate.isNotEmpty
                                        ? '$displayDate\n'
                                        : '';
                                    return BarTooltipItem(
                                      '$dateLine$val đồng',
                                      GoogleFonts.outfit(
                                        color: rodIndex == 0
                                            ? const Color(0xFF94A3B8)
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    );
                                  },
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
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= maxLen) {
                                    return const SizedBox.shrink();
                                  }

                                  final displayDate = dashboardChartPeriodLabel(
                                    currentData,
                                    previousData,
                                    idx,
                                  );

                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 10,
                                    child: Text(
                                      displayDate,
                                      style: GoogleFonts.manrope(
                                        color: c.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 92,
                                getTitlesWidget: (value, meta) {
                                  if (value == meta.max || value == meta.min) {
                                    return const SizedBox.shrink();
                                  }
                                  final label = compactVietnameseCurrency(
                                    value,
                                  );
                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 8,
                                    child: Text(
                                      label,
                                      style: GoogleFonts.manrope(
                                        color: c.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: barGroups,
                        ),
                      ),
                    ),
                  ),
                );
              }, // ends builder
            ), // ends LayoutBuilder
          ), // ends Expanded
        ], // ends Column children
      ), // ends Column
    ); // ends Container
  }

  Widget _buildLegendItem(String label, Color color, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String dashboardChartPeriodLabel(
  List<dynamic> currentData,
  List<dynamic> previousData,
  int index,
) {
  if (index < 0) return '';
  if (index < currentData.length) {
    final raw = currentData[index]['date']?.toString() ?? '';
    if (raw.isNotEmpty) return _formatDashboardPeriod(raw);
  }

  if (currentData.isNotEmpty) {
    final firstRaw = currentData.first['date']?.toString() ?? '';
    final parts = firstRaw.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null) {
        final projected = DateTime(year, month + index);
        return '${projected.month.toString().padLeft(2, '0')}/${projected.year}';
      }
    }
    final firstDate = DateTime.tryParse(firstRaw);
    if (firstDate != null) {
      final projected = firstDate.add(Duration(days: index));
      return '${projected.day.toString().padLeft(2, '0')}/${projected.month.toString().padLeft(2, '0')}';
    }
  }

  if (index < previousData.length) {
    return _formatDashboardPeriod(
      previousData[index]['date']?.toString() ?? '',
    );
  }
  return '';
}

String _formatDashboardPeriod(String raw) {
  final parts = raw.split('-');
  if (parts.length >= 3) return '${parts[2]}/${parts[1]}';
  if (parts.length == 2) return '${parts[1]}/${parts[0]}';
  return raw;
}

class TopProductsChart extends StatelessWidget {
  final List<dynamic> data;
  const TopProductsChart(this.data, {super.key});

  String _formatAmount(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}T đ';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M đ';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K đ';
    }
    return '${amount.toStringAsFixed(0)} đ';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    if (data.isEmpty) return const SizedBox.shrink();

    final maxVal = data.fold<double>(0.0, (m, e) {
      final v = num.tryParse(e['value']?.toString() ?? '0')?.toDouble() ?? 0.0;
      return v > m ? v : m;
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.divider.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 5 Sản phẩm doanh thu cao',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          ...data.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final val =
                num.tryParse(item['value']?.toString() ?? '0')?.toDouble() ??
                0.0;
            final percentage = maxVal > 0 ? val / maxVal : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['name']?.toString() ?? 'Unknown',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: c.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatAmount(val),
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                Container(
                                  height: 6,
                                  width: constraints.maxWidth,
                                  decoration: BoxDecoration(
                                    color: c.divider.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  height: 6,
                                  width: constraints.maxWidth * percentage,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class InventoryDonutChart extends StatefulWidget {
  final List<dynamic> data;
  const InventoryDonutChart(this.data, {super.key});

  @override
  State<InventoryDonutChart> createState() => _InventoryDonutChartState();
}

class _InventoryDonutChartState extends State<InventoryDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    if (widget.data.isEmpty) return const SizedBox.shrink();

    // Map data to chart format
    final total = widget.data.fold<double>(
      0,
      (sum, item) =>
          sum +
          (num.tryParse(item['value']?.toString() ?? '0')?.toDouble() ?? 0.0),
    );

    if (total == 0) {
      return Container(
        height: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.divider.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(
            'Chưa có dữ liệu tồn kho',
            style: TextStyle(color: c.textSecondary),
          ),
        ),
      );
    }
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Green
      const Color(0xFFF59E0B), // Orange
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEF4444), // Red
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFF43F5E), // Rose
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFEAB308), // Yellow
    ];

    final chartData = widget.data.asMap().entries.map((e) {
      final val =
          num.tryParse(e.value['value']?.toString() ?? '0')?.toDouble() ?? 0.0;
      final pct = total > 0 ? (val / total * 100) : 0.0;
      return {
        'name': e.value['name'],
        'value': pct,
        'color': colors[e.key % colors.length],
        'rawValue': val,
      };
    }).toList();

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.divider.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cơ cấu Hàng tồn kho (Theo Category)',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      sectionsSpace: 3,
                      centerSpaceRadius: 40,
                      sections: chartData.asMap().entries.map((entry) {
                        final i = entry.key;
                        final e = entry.value;
                        final isTouched = i == touchedIndex;
                        final double val = e['value'] as double;
                        final bool showText = val >= 5.0 || isTouched;
                        return PieChartSectionData(
                          color: e['color'] as Color,
                          value: val,
                          showTitle: showText,
                          title: showText ? '${val.toStringAsFixed(1)}%' : '',
                          radius: isTouched ? 45 : 35,
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          badgeWidget: isTouched
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1E293B,
                                    ).withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${e['name']}\n${val.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : null,
                          badgePositionPercentageOffset: 1.2,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: chartData.map((e) {
                        final pctStr = (e['value'] as double).toStringAsFixed(
                          1,
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: e['color'] as Color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${e['name']} ($pctStr%)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CashFlowAreaChart extends StatelessWidget {
  final List<dynamic> data;
  final String label;
  const CashFlowAreaChart(this.data, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    if (data.isEmpty) return const SizedBox.shrink();

    final spotsIncome = <FlSpot>[];
    final spotsExpense = <FlSpot>[];

    double maxY = 0;
    for (int i = 0; i < data.length; i++) {
      final inc =
          num.tryParse(data[i]['income']?.toString() ?? '0')?.toDouble() ?? 0.0;
      final exp =
          num.tryParse(data[i]['expense']?.toString() ?? '0')?.toDouble() ??
          0.0;
      spotsIncome.add(FlSpot(i.toDouble(), inc));
      spotsExpense.add(FlSpot(i.toDouble(), exp));
      if (inc > maxY) maxY = inc;
      if (exp > maxY) maxY = exp;
    }

    if (maxY == 0) maxY = 1000000;

    int expectedLen = data.length;
    if (expectedLen == 0) expectedLen = 1;

    // Pad with at least 1 point if there's only 1 day of data so the chart can draw a line
    if (data.length == 1) {
      spotsIncome.add(FlSpot(1.0, 0.0));
      spotsExpense.add(FlSpot(1.0, 0.0));
      expectedLen = 2;
    }

    double calculatedMaxX = (expectedLen - 1).toDouble();
    return Container(
      height: 280,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.divider.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dòng tiền ($label)',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textSecondary,
                    letterSpacing: -0.2,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Thu',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Chi',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double minWidth = expectedLen * 30.0;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.only(right: 16),
                    width: minWidth > constraints.maxWidth
                        ? minWidth
                        : constraints.maxWidth,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: c.divider.withValues(alpha: 0.15),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: 1,
                              getTitlesWidget: (v, m) {
                                if (v % 1 != 0) return const SizedBox.shrink();

                                final idx = v.toInt();
                                if (idx < 0 || idx > calculatedMaxX) {
                                  return const SizedBox.shrink();
                                }

                                String displayDate = '';
                                if (idx < data.length) {
                                  final dateStr =
                                      data[idx]['date'] as String? ?? '';
                                  final parts = dateStr.split('-');
                                  displayDate = parts.length >= 3
                                      ? '${parts[2]}/${parts[1]}'
                                      : dateStr;
                                } else if (data.isNotEmpty) {
                                  final firstDateStr =
                                      data.first['date'] as String? ?? '';
                                  final firstDate = DateTime.tryParse(
                                    firstDateStr,
                                  );
                                  if (firstDate != null) {
                                    final projectedDate = firstDate.add(
                                      Duration(days: idx),
                                    );
                                    final d = projectedDate.day
                                        .toString()
                                        .padLeft(2, '0');
                                    final m = projectedDate.month
                                        .toString()
                                        .padLeft(2, '0');
                                    displayDate = '$d/$m';
                                  }
                                }

                                if (displayDate.length < 5) {
                                  return const SizedBox.shrink();
                                }

                                int targetLen = calculatedMaxX.toInt() + 1;
                                if (targetLen > 7 &&
                                    idx % (targetLen / 5).ceil() != 0 &&
                                    idx != targetLen - 1) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    displayDate,
                                    style: GoogleFonts.outfit(
                                      color: c.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 52,
                              getTitlesWidget: (v, m) {
                                if (v == m.max || v == m.min) {
                                  return const SizedBox.shrink();
                                }
                                String lbl = v >= 1000000
                                    ? '${(v / 1000000).toStringAsFixed(0)}Tr'
                                    : (v >= 1000
                                          ? '${(v / 1000).toStringAsFixed(0)}K'
                                          : v.toStringAsFixed(0));
                                return Text(
                                  lbl,
                                  style: GoogleFonts.outfit(
                                    color: c.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.right,
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(
                              color: c.divider.withValues(alpha: 0.5),
                              width: 1,
                            ),
                            left: BorderSide.none,
                            right: BorderSide.none,
                            top: BorderSide.none,
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchSpotThreshold: 40,
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipColor: (_) =>
                                const Color(0xFF1E293B).withValues(alpha: 0.9),
                            tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            tooltipMargin: 8,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final val = NumberFormat.compact(
                                  locale: 'vi_VN',
                                ).format(spot.y);
                                final isIncome = spot.barIndex == 0;
                                return LineTooltipItem(
                                  '${isIncome ? "Thu" : "Chi"}: $val đ',
                                  GoogleFonts.outfit(
                                    color: isIncome
                                        ? const Color(0xFF60A5FA)
                                        : const Color(0xFFF87171),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        minX: 0,
                        maxX: calculatedMaxX,
                        minY: 0,
                        maxY: maxY * 1.15,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spotsIncome,
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: AppColors.success,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            shadow: Shadow(
                              color: AppColors.success.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.success.withValues(alpha: 0.35),
                                  AppColors.success.withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          LineChartBarData(
                            spots: spotsExpense,
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: AppColors.danger,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            shadow: Shadow(
                              color: AppColors.danger.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.danger.withValues(alpha: 0.35),
                                  AppColors.danger.withValues(alpha: 0.0),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LowStockTableWidget extends StatelessWidget {
  final List<dynamic> items;
  const LowStockTableWidget(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    if (items.isEmpty) return const SizedBox.shrink();
    final displayItems = items.take(5).toList();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Bảng Cảnh Báo Tồn Kho Dưới Định Mức',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => context.push('/inventory'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text(
                    'Quản lý kho',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.divider.withValues(alpha: 0.6)),

          // Table Columns Header
          Container(
            color: c.cardAlt.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'SẢN PHẨM',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TỒN KHAI BÁO',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'MỨC TỐI THIỂU',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TRẠNG THÁI',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'THAO TÁC',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.divider.withValues(alpha: 0.6)),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayItems.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: c.divider.withValues(alpha: 0.3)),
            itemBuilder: (context, index) {
              final item = displayItems[index];
              final name =
                  item['product']?['name'] ??
                  item['productName'] ??
                  item['name'] ??
                  'Sản phẩm';
              final qty =
                  item['currentQuantity'] ??
                  item['quantity'] ??
                  item['total_quantity'] ??
                  0;
              final minQty = item['minStock'] ?? item['min_quantity'] ?? 5;

              final isCritical = qty <= 0;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                color: index % 2 == 1
                    ? c.cardAlt.withValues(alpha: 0.2)
                    : Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$qty',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isCritical
                              ? AppColors.danger
                              : AppColors.warning,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$minQty',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          color: c.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isCritical
                                        ? AppColors.danger
                                        : AppColors.warning)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCritical ? 'Hết hàng' : 'Cần nhập thêm',
                            style: TextStyle(
                              color: isCritical
                                  ? AppColors.danger
                                  : AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: () =>
                              context.push('/purchase-orders/form'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'Nhập kho',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PaymentMethodDonutChart extends StatefulWidget {
  final List<dynamic> data;
  const PaymentMethodDonutChart(this.data, {super.key});

  @override
  State<PaymentMethodDonutChart> createState() =>
      _PaymentMethodDonutChartState();
}

class _PaymentMethodDonutChartState extends State<PaymentMethodDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    if (widget.data.isEmpty) return const SizedBox.shrink();

    final total = widget.data.fold<double>(
      0,
      (sum, item) =>
          sum +
          (num.tryParse(item['total']?.toString() ?? '0')?.toDouble() ?? 0.0),
    );

    if (total == 0) {
      return Container(
        height: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.divider.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(
            'Chưa có dữ liệu thanh toán',
            style: TextStyle(color: c.textSecondary),
          ),
        ),
      );
    }

    String getMethodName(String method) {
      if (method == 'CASH') return 'Tiền mặt';
      if (method == 'BANK_TRANSFER' || method == 'TRANSFER') {
        return 'Chuyển khoản';
      }
      if (method == 'CREDIT_CARD') return 'Thẻ tín dụng';
      if (method == 'DEBT') return 'Ghi nợ';
      return method;
    }

    Color getMethodColor(String method) {
      if (method == 'CASH') return AppColors.success;
      if (method == 'BANK_TRANSFER' || method == 'TRANSFER') {
        return theme.colorScheme.primary;
      }
      if (method == 'DEBT') return AppColors.warning;
      return AppColors.info;
    }

    final chartData = widget.data.map((item) {
      final val =
          num.tryParse(item['total']?.toString() ?? '0')?.toDouble() ?? 0.0;
      final pct = total > 0 ? (val / total * 100) : 0.0;
      final method = item['method']?.toString() ?? 'UNKNOWN';
      return {
        'name': getMethodName(method),
        'value': pct,
        'color': getMethodColor(method),
        'rawValue': val,
      };
    }).toList();

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.divider.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phương thức Thanh toán',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: chartData.asMap().entries.map((e) {
                        final isTouched = e.key == touchedIndex;
                        final fontSize = isTouched ? 14.0 : 11.0;
                        final radius = isTouched ? 45.0 : 40.0;
                        final val = e.value['value'] as double;
                        final bool showText = val >= 5.0 || isTouched;
                        return PieChartSectionData(
                          color: e.value['color'] as Color,
                          value: val,
                          showTitle: showText,
                          title: showText ? '${val.toStringAsFixed(1)}%' : '',
                          radius: radius,
                          titleStyle: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          badgeWidget: isTouched
                              ? Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    NumberFormat.compact(
                                      locale: 'vi_VN',
                                    ).format(e.value['rawValue']),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                )
                              : null,
                          badgePositionPercentageOffset: 1.3,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: chartData.length,
                    itemBuilder: (context, index) {
                      final item = chartData[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: item['color'] as Color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['name'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }
}

class RecentOrdersDataTable extends StatelessWidget {
  final List<dynamic> transactions;
  const RecentOrdersDataTable(this.transactions, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    if (transactions.isEmpty) return const SizedBox.shrink();
    final displayItems = transactions.take(6).toList();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedInvoice03,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Bảng Giao Dịch Đơn Hàng Gần Đây',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          ExcelExportService.exportOrdersToExcel(transactions),
                      icon: const Icon(Icons.table_chart_rounded, size: 14),
                      label: const Text(
                        'Xuất Excel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success.withValues(
                          alpha: 0.15,
                        ),
                        foregroundColor: AppColors.success,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => context.push('/sales'),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: const Text(
                        'Xem tất cả',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.divider.withValues(alpha: 0.6)),

          // Table Columns Header
          Container(
            color: c.cardAlt.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'MÃ ĐƠN',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'KHÁCH HÀNG',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'THỜI GIAN',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TỔNG TIỀN',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'THAO TÁC',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.divider.withValues(alpha: 0.6)),

          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayItems.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: c.divider.withValues(alpha: 0.3)),
            itemBuilder: (context, index) {
              final t = displayItems[index];
              final id = t['id'];
              final total =
                  num.tryParse(
                    t['totalAmount']?.toString() ?? '0',
                  )?.toDouble() ??
                  0.0;
              final dateStr = t['orderDate'] ?? '';
              final date = DateTime.tryParse(dateStr);
              final formattedDate = date != null
                  ? DateFormat('dd/MM HH:mm').format(date)
                  : '—';
              final customerName = t['customer']?['name'] ?? 'Khách mua lẻ';
              final orderCode = t['orderCode'] ?? 'HD-$id';

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                color: index % 2 == 1
                    ? c.cardAlt.withValues(alpha: 0.2)
                    : Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$orderCode',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        customerName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        formattedDate,
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _currFmt.format(total),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: () => context.push('/sales/$id'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Chi tiết',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class RecentDailyClosingsWidget extends ConsumerWidget {
  const RecentDailyClosingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final closingsAsync = ref.watch(dailyClosingsListProvider(1));

    return closingsAsync.when(
      loading: () => const SizedBox(height: 8),
      error: (_, _) => AppInlineError(
        message: 'Không thể tải lịch sử chốt ca.',
        onRetry: () => ref.invalidate(dailyClosingsListProvider(1)),
      ),
      data: (data) {
        final List<dynamic> items = (data['items'] as List?) ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.divider.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedInvoice03,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Bảng Lịch Sử Chốt Ca Gần Đây',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.divider.withValues(alpha: 0.6)),
              Container(
                color: c.cardAlt.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'NGÀY CHỐT',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'LÝ THUYẾT / THỰC TẾ',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'CHÊNH LỆCH',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.textSecondary,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.divider.withValues(alpha: 0.6)),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length > 5 ? 5 : items.length,
                separatorBuilder: (_, _) =>
                    Divider(color: c.divider.withValues(alpha: 0.3), height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final rawDate = item['closingDate'] ?? '';
                  String dateDisplay = rawDate;
                  try {
                    final date = DateTime.tryParse(rawDate);
                    if (date != null) {
                      dateDisplay = DateFormat('dd/MM/yyyy').format(date);
                    }
                  } catch (_) {}

                  final expected =
                      num.tryParse(
                        item['expectedCash']?.toString() ?? '0',
                      )?.toDouble() ??
                      0.0;
                  final actual =
                      num.tryParse(
                        item['actualCash']?.toString() ?? '0',
                      )?.toDouble() ??
                      0.0;
                  final diff =
                      num.tryParse(
                        item['cashDifference']?.toString() ?? '0',
                      )?.toDouble() ??
                      0.0;

                  Color diffColor = c.textPrimary;
                  String diffPrefix = '';
                  if (diff > 0) {
                    diffColor = Colors.orange;
                    diffPrefix = '+';
                  } else if (diff < 0) {
                    diffColor = AppColors.danger;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    color: index % 2 == 1
                        ? c.cardAlt.withValues(alpha: 0.2)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            dateDisplay,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'LÝ: ${_currFmt.format(expected)} • TT: ${_currFmt.format(actual)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            diff == 0
                                ? 'Khớp két'
                                : '$diffPrefix${_currFmt.format(diff)}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: diff == 0 ? AppColors.success : diffColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class DashboardHeroHeader extends ConsumerWidget {
  const DashboardHeroHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final shopState = ref.watch(shopProvider);
    final userName =
        authState.user?['name'] ??
        authState.user?['email']?.toString().split('@').first ??
        'Chủ cửa hàng';
    final shopName = shopState.currentShopName ?? 'Cửa hàng SmartStock';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 550;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.12),
                c.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: const [AppTheme.diffusionShadow],
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xin chào, $userName 👋',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: c.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$shopName • Mobile App',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: c.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/pos'),
                      icon: const Icon(Icons.flash_on_rounded, size: 16),
                      label: const Text('Bán Hàng (POS)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Xin chào, $userName 👋',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: c.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$shopName • Mobile App',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/pos'),
                      icon: const Icon(Icons.flash_on_rounded, size: 16),
                      label: const Text('Bán Hàng (POS)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UrgentBusinessPulseHeader — Highlight Key Alerts for Small Business Owner
// ─────────────────────────────────────────────────────────────────────────────
class UrgentBusinessPulseHeader extends ConsumerWidget {
  const UrgentBusinessPulseHeader({super.key});

  Widget _chip({
    required VoidCallback onTap,
    required Color color,
    required IconData icon,
    required String label,
    String? action,
  }) {
    return Builder(
      builder: (context) {
        final colors = AppThemeColors.of(context);
        return Material(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      action,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopState = ref.watch(shopProvider);
    final hasCustomers =
        shopState.isOwner || shopState.hasPermission('customers');
    final hasInventory =
        shopState.isOwner || shopState.hasPermission('inventory');
    final hasFinance =
        shopState.isOwner ||
        shopState.hasPermission('finance') ||
        shopState.hasPermission('dashboard');

    final chips = <Widget>[];

    if (hasCustomers) {
      final overdueAsync = ref.watch(overdueDebtsProvider);
      chips.add(
        overdueAsync.when(
          loading: () => _chip(
            onTap: () => context.push('/customer-debts'),
            color: Colors.blueGrey,
            icon: Icons.menu_book_outlined,
            label: 'Sổ nợ: Đang tải dữ liệu',
          ),
          error: (_, _) => _chip(
            onTap: () => context.push('/customer-debts'),
            color: Colors.blueGrey,
            icon: Icons.menu_book_outlined,
            label: 'Sổ nợ: Chưa tải được',
            action: 'Thử lại',
          ),
          data: (items) => _chip(
            onTap: () => context.push('/customer-debts'),
            color: items.isEmpty ? AppColors.success : Colors.orange,
            icon: items.isEmpty
                ? Icons.check_circle_outline
                : Icons.schedule_outlined,
            label: items.isEmpty
                ? 'Sổ nợ: Không có nợ quá hạn'
                : 'Sổ nợ: ${items.length} khoản quá hạn',
            action: items.isEmpty ? null : 'Xem nợ',
          ),
        ),
      );
    }

    if (hasInventory) {
      final lowStockAsync = ref.watch(lowStockProvider);
      chips.add(
        lowStockAsync.when(
          loading: () => _chip(
            onTap: () => context.push('/inventory'),
            color: Colors.blueGrey,
            icon: Icons.inventory_2_outlined,
            label: 'Kho hàng: Đang tải dữ liệu',
          ),
          error: (_, _) => _chip(
            onTap: () => context.push('/inventory'),
            color: Colors.blueGrey,
            icon: Icons.inventory_2_outlined,
            label: 'Kho hàng: Chưa tải được',
            action: 'Thử lại',
          ),
          data: (items) => _chip(
            onTap: () => context.push('/inventory'),
            color: items.isEmpty ? AppColors.success : AppColors.danger,
            icon: items.isEmpty
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            label: items.isEmpty
                ? 'Kho hàng: Không có hàng dưới định mức'
                : 'Kho hàng: ${items.length} SP dưới định mức',
            action: items.isEmpty ? null : 'Nhập kho',
          ),
        ),
      );
    }

    if (hasFinance) {
      final now = DateTime.now();
      final ytdFrom = '${now.year}-01-01';
      final ytdTo = now.toIso8601String().split('T')[0];
      final ytdSalesAsync = ref.watch(
        salesSummaryProvider((from: ytdFrom, to: ytdTo)),
      );
      final thresholds = ref.watch(taxConfigProvider).thresholds;

      chips.add(
        ytdSalesAsync.when(
          loading: () => _chip(
            onTap: () => context.push('/tax-calculator'),
            color: Colors.blueGrey,
            icon: Icons.account_balance_outlined,
            label: 'Thuế HKD 2026: Đang tải doanh thu',
          ),
          error: (_, _) => _chip(
            onTap: () => context.push('/tax-calculator'),
            color: Colors.blueGrey,
            icon: Icons.account_balance_outlined,
            label: 'Thuế HKD 2026: Chưa tải được',
            action: 'Kiểm tra',
          ),
          data: (data) {
            final revenue =
                num.tryParse(
                  data['totalRevenue']?.toString() ?? '0',
                )?.toDouble() ??
                0;
            final color = thresholds.getColor(revenue);
            return _chip(
              onTap: () => context.push('/tax-calculator'),
              color: color,
              icon: Icons.account_balance_outlined,
              label: 'Thuế HKD 2026: ${thresholds.getTierLabel(revenue)}',
              action: 'Chi tiết',
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < chips.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xs),
          chips[index],
        ],
      ],
    );
  }
}

class DashboardPriorityList extends ConsumerWidget {
  const DashboardPriorityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final shopState = ref.watch(shopProvider);
    final entries = <Widget>[];

    if (shopState.isOwner || shopState.hasPermission('finance')) {
      final today = DateTime.now();
      final salesAsync = ref.watch(
        salesSummaryProvider((
          from: '${today.year}-01-01',
          to: today.toIso8601String().split('T').first,
        )),
      );
      final thresholds = ref.watch(taxConfigProvider).thresholds;
      entries.add(
        salesAsync.when(
          loading: () => _PriorityRow(
            number: entries.length + 1,
            title: 'Kiểm tra nghĩa vụ thuế',
            detail: 'Đang tải doanh thu năm',
            status: 'Đang tải',
            statusColor: colors.textMuted,
            onTap: () => context.push('/tax-calculator'),
          ),
          error: (_, _) => _PriorityRow(
            number: entries.length + 1,
            title: 'Kiểm tra nghĩa vụ thuế',
            detail: 'Chưa tải được doanh thu năm',
            status: 'Kiểm tra',
            statusColor: AppColors.warning,
            onTap: () => context.push('/tax-calculator'),
          ),
          data: (data) {
            final revenue =
                num.tryParse(
                  data['totalRevenue']?.toString() ?? '0',
                )?.toDouble() ??
                0.0;
            return _PriorityRow(
              number: entries.length + 1,
              title: 'Thuế hộ kinh doanh ${today.year}',
              detail: thresholds.getTierLabel(revenue),
              status: 'Chi tiết',
              statusColor: thresholds.getColor(revenue),
              onTap: () => context.push('/tax-calculator'),
            );
          },
        ),
      );
    }

    if (shopState.isOwner || shopState.hasPermission('inventory')) {
      entries.add(
        ref
            .watch(lowStockProvider)
            .when(
              loading: () => _PriorityRow(
                number: entries.length + 1,
                title: 'Tồn kho cần xử lý',
                detail: 'Đang tải dữ liệu',
                status: 'Đang tải',
                statusColor: colors.textMuted,
                onTap: () => context.push('/inventory'),
              ),
              error: (_, _) => _PriorityRow(
                number: entries.length + 1,
                title: 'Tồn kho cần xử lý',
                detail: 'Chưa tải được dữ liệu',
                status: 'Kiểm tra',
                statusColor: AppColors.warning,
                onTap: () => context.push('/inventory'),
              ),
              data: (items) => _PriorityRow(
                number: entries.length + 1,
                title: items.isEmpty
                    ? 'Tồn kho trong định mức'
                    : '${items.length} sản phẩm dưới định mức tồn',
                detail: items.isEmpty
                    ? 'Chưa có sản phẩm cần nhập thêm'
                    : 'Kiểm tra và đề xuất nhập hàng',
                status: items.isEmpty ? 'Ổn định' : 'Cần xử lý',
                statusColor: items.isEmpty
                    ? AppColors.success
                    : AppColors.danger,
                onTap: () => context.push('/inventory'),
              ),
            ),
      );
    }

    if (shopState.isOwner || shopState.hasPermission('customers')) {
      entries.add(
        ref
            .watch(overdueDebtsProvider)
            .when(
              loading: () => _PriorityRow(
                number: entries.length + 1,
                title: 'Công nợ khách hàng',
                detail: 'Đang tải dữ liệu',
                status: 'Đang tải',
                statusColor: colors.textMuted,
                onTap: () => context.push('/customer-debts'),
              ),
              error: (_, _) => _PriorityRow(
                number: entries.length + 1,
                title: 'Công nợ khách hàng',
                detail: 'Chưa tải được dữ liệu',
                status: 'Kiểm tra',
                statusColor: AppColors.warning,
                onTap: () => context.push('/customer-debts'),
              ),
              data: (items) => _PriorityRow(
                number: entries.length + 1,
                title: items.isEmpty
                    ? 'Không có nợ quá hạn'
                    : '${items.length} khoản nợ quá hạn',
                detail: items.isEmpty
                    ? 'Công nợ đang trong hạn'
                    : 'Mở sổ nợ để theo dõi và thu nợ',
                status: items.isEmpty ? 'Ổn định' : 'Quá hạn',
                statusColor: items.isEmpty
                    ? AppColors.success
                    : AppColors.danger,
                onTap: () => context.push('/customer-debts'),
              ),
            ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Ưu tiên hôm nay',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Divider(height: 1, color: colors.divider),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Không có mục cần xử lý theo quyền hiện tại.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            )
          else
            for (var index = 0; index < entries.length; index++) ...[
              if (index > 0) Divider(height: 1, color: colors.divider),
              entries[index],
            ],
        ],
      ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  final int number;
  final String title;
  final String detail;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;

  const _PriorityRow({
    required this.number,
    required this.title,
    required this.detail,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$number',
                  style: AppTheme.tabularStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                status,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardRecentOrdersList extends StatelessWidget {
  final List<dynamic> transactions;

  const DashboardRecentOrdersList(this.transactions, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final displayItems = transactions.take(4).toList();

    if (displayItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.lg),
        child: AppEmpty(
          visual: AppEmptyVisual.sales,
          message: 'Chưa có đơn hàng gần đây',
          subtitle: 'Đơn hàng mới sẽ xuất hiện tại đây sau khi bán hàng.',
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [AppTheme.diffusionShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card - 1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 8, 11),
            child: Row(
              children: [
                AppAssetIcon(
                  assetPath: AppAssets.orders,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                  semanticLabel: 'Đơn hàng gần đây',
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Đơn hàng gần đây',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ExcelExportService.exportOrdersToExcel(transactions),
                  child: const Text('Xuất Excel'),
                ),
                TextButton(
                  onPressed: () => context.push('/sales'),
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 720) {
                return Column(
                  children: [
                    for (
                      var index = 0;
                      index < displayItems.length;
                      index++
                    ) ...[
                      if (index > 0) Divider(height: 1, color: colors.divider),
                      _RecentOrderMobileRow(item: displayItems[index]),
                    ],
                  ],
                );
              }

              return Column(
                children: [
                  Container(
                    color: colors.cardAlt.withValues(alpha: 0.92),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Mã đơn')),
                        Expanded(flex: 3, child: Text('Khách hàng')),
                        Expanded(flex: 2, child: Text('Ngày đặt')),
                        Expanded(
                          flex: 2,
                          child: Text('Giá trị', textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                  ),
                  for (var index = 0; index < displayItems.length; index++) ...[
                    if (index > 0) Divider(height: 1, color: colors.divider),
                    _RecentOrderDesktopRow(item: displayItems[index]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentOrderDesktopRow extends StatelessWidget {
  final dynamic item;

  const _RecentOrderDesktopRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final data = _RecentOrderData.from(item);

    return InkWell(
      onTap: () => context.push('/sales/${data.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                data.code,
                style: AppTheme.tabularStyle(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                data.customer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                data.date,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                data.total,
                textAlign: TextAlign.right,
                style: AppTheme.tabularStyle(
                  context,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentOrderMobileRow extends StatelessWidget {
  final dynamic item;

  const _RecentOrderMobileRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final data = _RecentOrderData.from(item);

    return InkWell(
      onTap: () => context.push('/sales/${data.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.code,
                    style: AppTheme.tabularStyle(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.customer,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  data.date,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  data.total,
                  style: AppTheme.tabularStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentOrderData {
  final dynamic id;
  final String code;
  final String customer;
  final String date;
  final String total;

  const _RecentOrderData({
    required this.id,
    required this.code,
    required this.customer,
    required this.date,
    required this.total,
  });

  factory _RecentOrderData.from(dynamic item) {
    final dateValue = DateTime.tryParse(item['orderDate']?.toString() ?? '');
    final amount =
        num.tryParse(item['totalAmount']?.toString() ?? '0')?.toDouble() ?? 0;
    final id = item['id'];
    return _RecentOrderData(
      id: id,
      code: item['orderCode']?.toString() ?? 'HD-$id',
      customer: item['customer']?['name']?.toString() ?? 'Khách mua lẻ',
      date: dateValue == null
          ? 'Chưa rõ'
          : DateFormat('dd/MM/yyyy HH:mm').format(dateValue),
      total: _currFmt.format(amount),
    );
  }
}
