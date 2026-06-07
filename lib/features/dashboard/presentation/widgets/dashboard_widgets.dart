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
  const SummaryCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: c.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: icon, size: 24, color: color),
              ),
              // Subtle dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: c.textPrimary,
              letterSpacing: -1.5,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(color: Colors.transparent),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.divider, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: HugeIcon(
                icon: icon,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBtn(context, 'week', 'Tuần này', theme, c),
          _buildBtn(context, 'month', 'Tháng này', theme, c),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? theme.colorScheme.primary : c.textSecondary,
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
  const ComparisonBarChart(
    this.currentData,
    this.previousData,
    this.label1,
    this.label2,
  );

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

    // Create grouped data
    final barGroups = <BarChartGroupData>[];
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
              color: c.textMuted.withValues(alpha: 0.4),
              width: 12,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: rev1,
              color: theme.colorScheme.primary,
              width: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          barsSpace: 4,
        ),
      );
    }

    if (maxRev == 0) maxRev = 1000000;

    return Container(
      height: 240,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(left: 4, right: 16, top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'So sánh doanh thu',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    _buildLegendItem(
                      label2,
                      c.textMuted.withValues(alpha: 0.4),
                      c.textMuted,
                    ),
                    const SizedBox(width: 12),
                    _buildLegendItem(
                      label1,
                      theme.colorScheme.primary,
                      c.textSecondary,
                    ),
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
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => c.surface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final val = NumberFormat.compact(
                        locale: 'vi_VN',
                      ).format(rod.toY);
                      final label = rodIndex == 0 ? label2 : label1;
                      return BarTooltipItem(
                        '$label\n$val',
                        GoogleFonts.outfit(
                          color: rodIndex == 0
                              ? c.textSecondary
                              : theme.colorScheme.primary,
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
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= currentData.length)
                          return const SizedBox.shrink();
                        final dateStr =
                            currentData[idx]['date'] as String? ?? '';
                        if (dateStr.length < 5) return const SizedBox.shrink();
                        final parts = dateStr.split('-');
                        final displayDate = parts.length >= 3
                            ? '${parts[2]}/${parts[1]}'
                            : dateStr;

                        // Limit labels if too many
                        if (currentData.length > 7 &&
                            idx % (currentData.length / 5).ceil() != 0 &&
                            idx != currentData.length - 1) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            displayDate,
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: c.divider.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
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
      height: 250,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.divider.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
              const SizedBox(height: 20),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceBetween,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => c.surface,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final val = NumberFormat.compact(
                            locale: 'vi_VN',
                          ).format(rod.toY);
                          return BarTooltipItem(
                            '${data[group.x.toInt()]['name']}\n$val đ',
                            GoogleFonts.outfit(
                              color: theme.colorScheme.primary,
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
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.max || value == meta.min)
                              return const SizedBox.shrink();
                            String label = '';
                            if (value >= 1000000) {
                              label =
                                  '${(value / 1000000).toStringAsFixed(0)}Tr';
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 80,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= data.length)
                              return const SizedBox.shrink();
                            final name = data[idx]['name'] as String;
                            final shortName = name.length > 12
                                ? '${name.substring(0, 10)}...'
                                : name;
                            return Text(
                              shortName,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      drawHorizontalLine: false,
                      getDrawingVerticalLine: (value) => FlLine(
                        color: c.divider.withValues(alpha: 0.3),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: data.asMap().entries.map((entry) {
                      final val =
                          num.tryParse(
                            entry.value['value']?.toString() ?? '0',
                          )?.toDouble() ??
                          0.0;
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: val,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.8,
                            ),
                            width: 14,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(4),
                              bottomRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  duration: const Duration(milliseconds: 300),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryDonutChart extends StatelessWidget {
  final List<dynamic> data;
  const InventoryDonutChart(this.data);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    if (data.isEmpty) return const SizedBox.shrink();

    // Map data to chart format
    final total = data.fold<double>(
      0,
      (sum, item) =>
          sum +
          (num.tryParse(item['value']?.toString() ?? '0')?.toDouble() ?? 0.0),
    );
    final colors = [
      AppColors.success,
      AppColors.info,
      AppColors.warning,
      theme.colorScheme.primary,
      AppColors.danger,
      Colors.purple,
      Colors.teal,
    ];

    final chartData = data.asMap().entries.map((e) {
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
      height: 250,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.divider.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: chartData.map((e) {
                            return PieChartSectionData(
                              color: e['color'] as Color,
                              value: e['value'] as double,
                              title:
                                  '${(e['value'] as double).toStringAsFixed(1)}%',
                              radius: 20,
                              titleStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: chartData.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: e['color'] as Color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e['name'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: c.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

    return Container(
      height: 240,
      padding: const EdgeInsets.only(left: 4, right: 16, top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.divider.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dòng tiền ($label)',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.textSecondary,
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
                    const SizedBox(width: 4),
                    Text(
                      'Thu',
                      style: TextStyle(
                        fontSize: 10,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Chi',
                      style: TextStyle(
                        fontSize: 10,
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
                    color: c.divider.withValues(alpha: 0.2),
                    strokeWidth: 1,
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
                      reservedSize: 22,
                      getTitlesWidget: (v, m) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= data.length)
                          return const SizedBox.shrink();
                        if (data.length > 7 &&
                            idx % (data.length / 5).ceil() != 0 &&
                            idx != data.length - 1)
                          return const SizedBox.shrink();
                        final dateStr = data[idx]['date'] as String? ?? '';
                        if (dateStr.length < 5) return const SizedBox.shrink();
                        final parts = dateStr.split('-');
                        final displayDate = parts.length >= 3
                            ? '${parts[2]}/${parts[1]}'
                            : dateStr;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            displayDate,
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
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
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY: maxY * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spotsIncome,
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: spotsExpense,
                    isCurved: true,
                    color: AppColors.danger,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.danger.withValues(alpha: 0.1),
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
