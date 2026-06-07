import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/chart_widgets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../finance/providers/finance_provider.dart';
import '../../../settings/providers/tax_config_provider.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '?',
  decimalDigits: 0,
);

class TaxObligationReminder extends ConsumerWidget {
  const TaxObligationReminder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final taxAsync = ref.watch(taxObligationsProvider);

    return taxAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
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
              final totalOwed = vatOwed + pitOwed;
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
  const SummaryCard(
    this.title,
    this.value,
    this.icon,
    this.color, {
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    
    final bgGradient = isHero
        ? LinearGradient(
            colors: [color, color.withAlpha(220)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    final bgColor = isHero ? null : c.surface;
    final textColor = isHero ? Colors.white : c.textPrimary;
    final subTextColor = isHero
        ? Colors.white.withValues(alpha: 0.9)
        : c.textSecondary;
    final iconBg = isHero
        ? Colors.white.withValues(alpha: 0.2)
        : color.withValues(alpha: 0.1);
    final iconColor = isHero ? Colors.white : color;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isHero 
              ? Colors.white.withValues(alpha: 0.15) 
              : c.divider.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isHero ? 0.25 : 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          if (isHero)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.1),
              blurRadius: 0,
              spreadRadius: 1,
              offset: const Offset(0, 1),
            )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(icon: icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: subTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
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
  const QuickAction(this.icon, this.label, this.onTap);

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
  const TimeFilterBar(this.currentFilter, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.cardAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBtn(context, 'week', 'Tuần này', theme, c),
            _buildBtn(context, 'month', 'Tháng này', theme, c),
            _buildBtn(context, '6_months', '6 Tháng', theme, c),
            _buildBtn(context, 'year', 'Năm nay', theme, c),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.card : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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

class ComparisonBarChart extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    if (currentData.isEmpty && previousData.isEmpty) {
      return Container(
        height: 220,
        margin: const EdgeInsets.only(top: 14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.divider.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAnalytics01,
                size: 32,
                color: c.textMuted,
              ),
              const SizedBox(height: 8),
              Text(
                'Chưa có dữ liệu giao dịch',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            ],
          ),
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
      barWidth = isMobile ? 8.0 : 16.0;
      bSpace = isMobile ? 6.0 : 12.0;
    } else {
      barWidth = isMobile ? 3.0 : 8.0;
      bSpace = isMobile ? 2.0 : 4.0;
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
              gradient: LinearGradient(
                colors: [pastColor, pastColor.withValues(alpha: 0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              width: barWidth,
              borderRadius: BorderRadius.circular(100),
            ),
            BarChartRodData(
              toY: rev1,
              gradient: LinearGradient(
                colors: [presentColor, presentColor.withValues(alpha: 0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              width: barWidth,
              borderRadius: BorderRadius.circular(100),
            ),
          ],
          barsSpace: bSpace,
        ),
      );
    }

    if (maxRev == 0) maxRev = 1000000;

    return Container(
      height: 380,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'So sánh doanh thu',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textSecondary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (filterWidget != null) ...[
                      const SizedBox(width: 16),
                      filterWidget!,
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem(label2, pastColor, c.textSecondary),
                    const SizedBox(width: 16),
                    _buildLegendItem(label1, presentColor, c.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxRev * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: c.divider.withValues(alpha: 0.15),
                    strokeWidth: 1,
                    dashArray: [5, 5],
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
                    getTooltipColor: (group) =>
                        const Color(0xFF1E293B).withValues(alpha: 0.9),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final val = NumberFormat.compact(
                        locale: 'vi_VN',
                      ).format(rod.toY);
                      final idx = group.x;
                      String dateStr = '';
                      if (rodIndex == 0 && idx < previousData.length) {
                          dateStr = previousData[idx]['date'] as String? ?? '';
                      } else if (rodIndex == 1 && idx < currentData.length) {
                          dateStr = currentData[idx]['date'] as String? ?? '';
                      }
                      
                      final parts = dateStr.split('-');
                      String displayDate = dateStr;
                      if (parts.length >= 3) {
                          displayDate = '${parts[2]}/${parts[1]}/${parts[0]}';
                      } else if (parts.length == 2) {
                          displayDate = '${parts[1]}/${parts[0]}';
                      }

                      final label = rodIndex == 0 ? label2 : label1;
                      final dateLine = displayDate.isNotEmpty ? '$displayDate\n' : '';
                      return BarTooltipItem(
                        '$dateLine$label\n$val đ',
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
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= maxLen)
                          return const SizedBox.shrink();

                        String displayDate = '';
                        if (idx < currentData.length) {
                          final dateStr =
                              currentData[idx]['date'] as String? ?? '';
                          final parts = dateStr.split('-');
                          displayDate = parts.length >= 3
                              ? '${parts[2]}/${parts[1]}'
                              : dateStr;
                        } else if (currentData.isNotEmpty) {
                          // Project forward from the first day
                          final firstDateStr =
                              currentData.first['date'] as String? ?? '';
                          final firstDate = DateTime.tryParse(firstDateStr);
                          if (firstDate != null) {
                            final projectedDate = firstDate.add(
                              Duration(days: idx),
                            );
                            final d = projectedDate.day.toString().padLeft(
                              2,
                              '0',
                            );
                            final m = projectedDate.month.toString().padLeft(
                              2,
                              '0',
                            );
                            displayDate = '$d/$m';
                          }
                        } else if (idx < previousData.length) {
                          final dateStr =
                              previousData[idx]['date'] as String? ?? '';
                          final parts = dateStr.split('-');
                          displayDate = parts.length >= 3
                              ? '${parts[2]}/${parts[1]}'
                              : dateStr;
                        }

                        if (displayDate.length < 5)
                          return const SizedBox.shrink();

                        // Limit labels if too many
                        if (maxLen > 7 &&
                            idx % (maxLen / 5).ceil() != 0 &&
                            idx != maxLen - 1) {
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
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min)
                          return const SizedBox.shrink();
                        String label = '';
                        if (value >= 1000000) {
                          label = '${(value / 1000000).toStringAsFixed(0)}Tr';
                        } else if (value >= 1000) {
                          label = '${(value / 1000).toStringAsFixed(0)}K';
                        } else {
                          label = value.toStringAsFixed(0);
                        }
                        return Text(
                          label,
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        );
                      },
                    ),
                  ),
                ),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
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

class TopProductsChart extends StatelessWidget {
  final List<dynamic> data;
  const TopProductsChart(this.data);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    if (data.isEmpty) return const SizedBox.shrink();

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
            'Top 5 Sản phẩm doanh thu cao',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => theme.colorScheme.primary,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final val = NumberFormat.compact(
                        locale: 'vi_VN',
                      ).format(rod.toY);
                      return BarTooltipItem(
                        '${data[group.x.toInt()]['name']}\n$val đ',
                        GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
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
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length)
                          return const SizedBox.shrink();
                        final name = data[idx]['name'] as String;
                        final shortName = name.length > 8
                            ? '${name.substring(0, 8)}...'
                            : name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            shortName,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min)
                          return const SizedBox.shrink();
                        String label = '';
                        if (value >= 1000000) {
                          label = '${(value / 1000000).toStringAsFixed(0)}Tr';
                        } else if (value >= 1000) {
                          label = '${(value / 1000).toStringAsFixed(0)}K';
                        } else {
                          label = value.toStringAsFixed(0);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            label,
                            style: TextStyle(
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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  drawHorizontalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: c.divider.withValues(alpha: 0.15),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: (() {
                  final maxVal = data.fold<double>(0.0, (m, e) {
                    final v = num.tryParse(e['value']?.toString() ?? '0')?.toDouble() ?? 0.0;
                    return v > m ? v : m;
                  });
                  return data.asMap().entries.map((entry) {
                    final val = num.tryParse(entry.value['value']?.toString() ?? '0')?.toDouble() ?? 0.0;
                    return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: theme.colorScheme.primary,
                        width: 32,
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal * 1.1 == 0 ? 100 : maxVal * 1.1,
                          color: c.divider.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  );
                }).toList();
              })(),
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryDonutChart extends StatefulWidget {
  final List<dynamic> data;
  const InventoryDonutChart(this.data);

  @override
  State<InventoryDonutChart> createState() => _InventoryDonutChartState();
}

class _InventoryDonutChartState extends State<InventoryDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

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
          child: Text('Chưa có dữ liệu tồn kho', style: TextStyle(color: c.textSecondary)),
        ),
      );
    }
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.primary.withValues(alpha: 0.8),
      theme.colorScheme.primary.withValues(alpha: 0.6),
      theme.colorScheme.primary.withValues(alpha: 0.4),
      theme.colorScheme.primary.withValues(alpha: 0.2),
      AppColors.info,
      AppColors.warning,
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
                            touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sectionsSpace: 3,
                      centerSpaceRadius: 40,
                      sections: chartData.asMap().entries.map((entry) {
                        final i = entry.key;
                        final e = entry.value;
                        final isTouched = i == touchedIndex;
                        return PieChartSectionData(
                          color: e['color'] as Color,
                          value: e['value'] as double,
                          showTitle: isTouched,
                          title: isTouched ? '${e['name']}\n${(e['value'] as double).toStringAsFixed(1)}%' : '',
                          radius: isTouched ? 45 : 35,
                          titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
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
                        final pctStr = (e['value'] as double).toStringAsFixed(1);
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
  const CashFlowAreaChart(this.data, this.label);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

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
                        color: theme.colorScheme.primary,
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
                        if (idx < 0 || idx > calculatedMaxX)
                          return const SizedBox.shrink();

                        String displayDate = '';
                        if (idx < data.length) {
                          final dateStr = data[idx]['date'] as String? ?? '';
                          final parts = dateStr.split('-');
                          displayDate = parts.length >= 3
                              ? '${parts[2]}/${parts[1]}'
                              : dateStr;
                        } else if (data.isNotEmpty) {
                          final firstDateStr =
                              data.first['date'] as String? ?? '';
                          final firstDate = DateTime.tryParse(firstDateStr);
                          if (firstDate != null) {
                            final projectedDate = firstDate.add(
                              Duration(days: idx),
                            );
                            final d = projectedDate.day.toString().padLeft(
                              2,
                              '0',
                            );
                            final m = projectedDate.month.toString().padLeft(
                              2,
                              '0',
                            );
                            displayDate = '$d/$m';
                          }
                        }

                        if (displayDate.length < 5)
                          return const SizedBox.shrink();

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
                        if (v == m.max || v == m.min)
                          return const SizedBox.shrink();
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
                    color: theme.colorScheme.primary,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    shadow: Shadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.35),
                          theme.colorScheme.primary.withValues(alpha: 0.0),
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
        ],
      ),
    );
  }
}
