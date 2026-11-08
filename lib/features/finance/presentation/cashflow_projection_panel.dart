import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../providers/finance_provider.dart';
import 'cashflow_daily_details.dart';
import 'cashflow_forecast_screen.dart';
import 'cashflow_plan_list.dart';

class CashflowProjectionPanel extends ConsumerWidget {
  const CashflowProjectionPanel({super.key});
  static num _amount(dynamic value) => num.tryParse('$value') ?? 0;
  static String _money(dynamic value) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(_amount(value));
  static String _date(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    return parsed == null ? '$value' : DateFormat('dd/MM/yyyy').format(parsed);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa kế hoạch bổ sung?'),
        content: const Text(
          'Thao tác này chỉ xóa khoản dự kiến. Chứng từ thu/chi đã ghi được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa kế hoạch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(financeRepoProvider).deleteForecast(id);
      ref.invalidate(forecastsProvider);
    } catch (_) {
      ToastService.showError('Không thể xóa kế hoạch. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final theme = Theme.of(context);
    return ref
        .watch(cashflowProjectionProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => AppInlineError(
            message: 'Không thể tải dự báo dòng tiền.',
            onRetry: () => ref.invalidate(cashflowProjectionProvider),
          ),
          data: (projection) {
            final days = (projection['daily'] as List? ?? [])
                .whereType<Map>()
                .toList();
            final book = _amount(projection['bookBalance']).toDouble();
            final points = [
              const FlSpot(0, 0),
              ...days.asMap().entries.map(
                (entry) => FlSpot(
                  entry.key + 1.0,
                  _amount(entry.value['balance']).toDouble() - book,
                ),
              ),
            ];
            final plans = ref.watch(forecastsProvider).asData?.value ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Dự báo 30 ngày tới',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Làm mới dự báo',
                      onPressed: () =>
                          ref.invalidate(cashflowProjectionProvider),
                      icon: const AppIcon(Icons.refresh),
                    ),
                  ],
                ),
                Text(
                  'Số dư theo sổ đến ${_date(projection['asOf'])}. Công nợ dự kiến theo hạn thanh toán đã ghi.',
                  style: TextStyle(color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ước tính theo lịch thu/chi đã ghi, không phải tiền chắc chắn có hoặc lợi nhuận dự kiến.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                TextButton.icon(
                  icon: const AppIcon(Icons.info_outline),
                  label: const Text('Cơ sở và giới hạn dự báo'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Cơ sở dự báo dòng tiền'),
                      scrollable: true,
                      content: const SelectableText(
                        'Số dư cuối ngày = số dư đầu ngày + thu dự kiến − chi dự kiến. Số dư cuối ngày trước là số dư đầu ngày sau.\n\n'
                        'Số dư đầu kỳ lấy tiền mặt và ngân hàng theo sổ đến hôm nay, gồm điều chỉnh số dư ban đầu. Thu/chi dự kiến gồm phần công nợ chưa thanh toán theo hạn đã ghi và kế hoạch bổ sung trong 30 ngày tiếp theo.\n\n'
                        'Giả định công nợ được thu/trả đúng hạn và kế hoạch diễn ra đúng ngày, đúng số tiền. Khoản quá hạn được trình bày riêng, chưa tự dời sang ngày mới. Chưa ước tính doanh thu chưa ghi nhận, mùa vụ hay xác suất khách thanh toán.\n\n'
                        'Chỉ nhập kế hoạch cho khoản chưa có trong công nợ. Khi phát sinh thu/chi thật, cần đối chiếu kế hoạch tương ứng để tránh tính trùng. Dự báo không tự ghi tiền, tạo khoản nợ hoặc thay đổi tồn kho.\n\n'
                        'Tham khảo phương pháp lập dòng tiền: Australian Government — Set up a cash flow statement (business.gov.au/finance/cash-flow/set-up-a-cash-flow-statement); British Business Bank — How to create a cash flow forecast in 4 steps. Đây là phương pháp tham khảo, không phải chứng nhận số liệu của cửa hàng.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Đã hiểu'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 680
                        ? (constraints.maxWidth - 24) / 3
                        : constraints.maxWidth;
                    Widget metric(String title, dynamic value) => SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.card,
                          border: Border.all(color: colors.divider),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(color: colors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _money(value),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        metric('Số dư theo sổ', projection['bookBalance']),
                        metric(
                          'Thu dự kiến trong kỳ',
                          projection['expectedIncome'],
                        ),
                        metric(
                          'Số dư cuối kỳ dự kiến',
                          projection['closingBalance'],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Chi dự kiến trong kỳ: ${_money(projection['expectedExpense'])}',
                  style: TextStyle(color: colors.textSecondary),
                ),
                if (projection['firstShortfallDate'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Dự kiến thiếu tiền từ ${_date(projection['firstShortfallDate'])}.',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Biến động so với số dư theo sổ',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.divider),
                  ),
                  child: SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: days.length.toDouble().clamp(1, 365).toDouble(),
                        lineBarsData: [
                          LineChartBarData(
                            spots: points,
                            isCurved: false,
                            color: theme.colorScheme.primary,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 76,
                              getTitlesWidget: (value, meta) => Text(
                                compactVietnameseAmount(value),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 10,
                              reservedSize: 34,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                final date = index == 0
                                    ? projection['asOf']
                                    : index <= days.length
                                    ? days[index - 1]['date']
                                    : null;
                                if (date == null) {
                                  return const SizedBox.shrink();
                                }
                                final parsed = DateTime.tryParse('$date');
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    parsed == null
                                        ? ''
                                        : DateFormat('dd/MM').format(parsed),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) => spots
                                .map(
                                  (spot) => LineTooltipItem(
                                    '${_date(spot.x.toInt() == 0 ? projection['asOf'] : days[spot.x.toInt() - 1]['date'])}\nSố dư: ${_money(spot.y + book)}\nChênh lệch: ${_money(spot.y)}',
                                    const TextStyle(color: Colors.white),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      showCashflowDailyDetails(context, projection),
                  icon: const AppIcon(Icons.table_rows_outlined),
                  label: const Text('Xem cách tính theo ngày'),
                ),
                const SizedBox(height: 12),
                if (_amount(projection['dueIncome']) > 0 ||
                    _amount(projection['dueExpense']) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Đã đến hạn, chưa xử lý: phải thu ${_money(projection['dueIncome'])}, phải trả ${_money(projection['dueExpense'])}. Các khoản này chưa cộng vào dự báo vì chưa có ngày thu/chi mới.',
                    ),
                  ),
                const Divider(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kế hoạch bổ sung',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chỉ nhập khoản chưa có trong công nợ. Khi đã ghi thu/chi thực tế, cập nhật hoặc xóa kế hoạch tương ứng để tránh tính trùng.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Thêm kế hoạch'),
                      onPressed: () => showAddForecastDialog(context, ref),
                    ),
                  ],
                ),
                CashflowPlanList(
                  plans: plans,
                  asOf: '${projection['asOf']}',
                  throughDate:
                      '${projection['throughDate'] ?? (days.isEmpty ? projection['asOf'] : days.last['date'])}',
                  onDelete: (id) => _remove(context, ref, id),
                ),
              ],
            );
          },
        );
  }
}
