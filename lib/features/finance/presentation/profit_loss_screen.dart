import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/custom_date_range_picker.dart';
import '../../../core/utils/type_parser.dart';
import '../providers/finance_provider.dart';

class ProfitLossScreen extends ConsumerStatefulWidget {
  const ProfitLossScreen({super.key});
  @override
  ConsumerState<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends ConsumerState<ProfitLossScreen> {
  late DateTimeRange _range;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
  }

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

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
    final label = '${DateFormat('dd/MM').format(_range.start)} - ${DateFormat('dd/MM').format(_range.end)}';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Báo cáo Kết quả Kinh doanh',
          style: GoogleFonts.outfit(
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
            label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          featureGuideButton(context, 'profit_loss'),
        ],
      ),
      body: plAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e', style: TextStyle(color: AppColors.danger))),
        data: (data) {
          final revenue = TypeParser.asDouble(data['revenue']);
          final cogs = TypeParser.asDouble(data['cogs']);
          final grossProfit = TypeParser.asDouble(data['grossProfit']);
          final expenses = TypeParser.asDouble(data['expenses']);
          final netProfit = TypeParser.asDouble(data['netProfit']);
          final grossPct = revenue > 0 ? (grossProfit / revenue * 100).toStringAsFixed(1) : '0.0';
          final netPct = revenue > 0 ? (netProfit / revenue * 100).toStringAsFixed(1) : '0.0';
          
          final cogsPct = revenue > 0 ? (cogs / revenue * 100).toStringAsFixed(1) : '0.0';
          final expensesPct = revenue > 0 ? (expenses / revenue * 100).toStringAsFixed(1) : '0.0';

          if (revenue == 0 && cogs == 0 && expenses == 0) {
            return const AppEmpty(
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08), 
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 16, color: theme.colorScheme.primary), 
                      const SizedBox(width: 8), 
                      Text(
                        'Kỳ đối chiếu: $from → $to', 
                        style: GoogleFonts.outfit(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Vibrant Chart Card (Glassmorphic Container with Pie Chart)
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: c.divider.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Builder(
                    builder: (context) {
                      final sectionsList = <({Color color, double value, String pct, String title})>[];
                      if (netProfit > 0) {
                        sectionsList.add((color: AppColors.success, value: netProfit.toDouble(), pct: '$netPct%', title: 'Lợi nhuận ròng'));
                      }
                      if (cogs > 0) {
                        sectionsList.add((color: AppColors.danger, value: cogs.toDouble(), pct: '$cogsPct%', title: 'Giá vốn (COGS)'));
                      }
                      if (expenses > 0) {
                        sectionsList.add((color: AppColors.warning, value: expenses.toDouble(), pct: '$expensesPct%', title: 'Vận hành (OPEX)'));
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cơ cấu dòng tiền & Lợi nhuận',
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Phân bổ dòng tiền dựa trên tổng doanh thu',
                            style: TextStyle(fontSize: 11, color: c.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              // Pie Chart
                              SizedBox(
                                width: 130,
                                height: 130,
                                child: PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                        setState(() {
                                          if (!event.isInterestedForInteractions ||
                                              pieTouchResponse == null ||
                                              pieTouchResponse.touchedSection == null) {
                                            _touchedIndex = -1;
                                            return;
                                          }
                                          _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                        });
                                      },
                                    ),
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 30,
                                    startDegreeOffset: -90,
                                    sections: List.generate(sectionsList.length, (index) {
                                      final isTouched = index == _touchedIndex;
                                      final item = sectionsList[index];
                                      final double radius = isTouched ? 36.0 : 28.0;
                                      return PieChartSectionData(
                                        color: item.color,
                                        value: item.value,
                                        title: item.pct,
                                        radius: radius,
                                        titleStyle: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: isTouched ? 12 : 10,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Legends
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _ChartLegend('Lợi nhuận ròng', AppColors.success, '$netPct%'),
                                    const SizedBox(height: 10),
                                    _ChartLegend('Giá vốn (COGS)', AppColors.danger, '$cogsPct%'),
                                    const SizedBox(height: 10),
                                    _ChartLegend('Vận hành (OPEX)', AppColors.warning, '$expensesPct%'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_touchedIndex >= 0 && _touchedIndex < sectionsList.length) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: sectionsList[_touchedIndex].color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: sectionsList[_touchedIndex].color.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: sectionsList[_touchedIndex].color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    sectionsList[_touchedIndex].title,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _fmt(sectionsList[_touchedIndex].value),
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: sectionsList[_touchedIndex].color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    }
                  ),
                ),
                
                // Metrics grid list
                _MetricCard('Tổng doanh thu bán hàng', _fmt(revenue), theme.colorScheme.primary, Icons.trending_up_rounded),
                _MetricCard('Giá vốn hàng bán (COGS)', _fmt(cogs), AppColors.danger, Icons.shopping_cart_rounded),
                
                // Gross Profit Card (Emerald highlighted)
                Container(
                  padding: const EdgeInsets.all(16), 
                  margin: const EdgeInsets.only(bottom: 12), 
                  decoration: BoxDecoration(
                    color: c.card, 
                    borderRadius: BorderRadius.circular(24), 
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8), 
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), 
                        child: const Icon(Icons.auto_graph_rounded, color: AppColors.success, size: 20)
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text('Lợi nhuận gộp', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)), 
                            const SizedBox(height: 2),
                            Text(
                              _fmt(grossProfit), 
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.success)
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(30)), 
                        child: Text(
                          '$grossPct%', 
                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)
                        ),
                      ),
                    ],
                  ),
                ),
                
                _MetricCard('Chi phí vận hành (OPEX)', _fmt(expenses), AppColors.warning, Icons.settings_suggest_rounded),
                
                // Net Profit Card (Dynamic Brand-Gradient themed)
                Container(
                  padding: const EdgeInsets.all(18), 
                  margin: const EdgeInsets.only(bottom: 20), 
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ), 
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8), 
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)), 
                        child: const Icon(Icons.stars_rounded, color: Colors.white, size: 20)
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text(
                              'Lợi nhuận ròng (P&L)', 
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w500)
                            ), 
                            const SizedBox(height: 2),
                            Text(
                              _fmt(netProfit), 
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(30)), 
                        child: Text(
                          '$netPct%', 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                Text(
                  'Chi tiết danh mục tài khoản', 
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)
                ),
                const SizedBox(height: 12),
                
                _DetailRow('Doanh thu bán lẻ quầy', _fmt(revenue), true),
                _DetailRow('Giá vốn nhập hàng kho', _fmt(cogs), false),
                _DetailRow('Chi phí vận hành & chi khác', _fmt(expenses), false),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value; 
  final Color color; 
  final IconData icon;
  const _MetricCard(this.label, this.value, this.color, this.icon);
  
  @override 
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16), 
      margin: const EdgeInsets.only(bottom: 12), 
      decoration: BoxDecoration(
        color: c.card, 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.divider.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8), 
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), 
            child: Icon(icon, color: color, size: 20)
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(
                  label, 
                  style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ), 
                const SizedBox(height: 4),
                Text(
                  value, 
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, 
                    fontSize: 20, 
                    color: color,
                    letterSpacing: -0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, amount; 
  final bool isIncome;
  const _DetailRow(this.label, this.amount, this.isIncome);
  
  @override 
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8), 
      padding: const EdgeInsets.all(14), 
      decoration: BoxDecoration(
        color: c.card, 
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.divider.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Expanded(
            child: Text(
              label, 
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // Prevention of text overflow
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount, 
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, 
              fontSize: 14,
              color: isIncome ? AppColors.success : AppColors.danger
            )
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final String label;
  final Color color;
  final String pct;
  const _ChartLegend(this.label, this.color, this.pct);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          pct,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary),
        ),
      ],
    );
  }
}

