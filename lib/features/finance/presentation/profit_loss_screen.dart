import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/type_parser.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/custom_date_range_picker.dart';
import '../../../core/widgets/responsive_layout.dart';
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
    _range = DateTimeRange(start: DateTime(now.year, now.month), end: now);
  }

  String _key(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
  String _period(DateTimeRange value) =>
      '${DateFormat('dd/MM/yyyy').format(value.start)} – '
      '${DateFormat('dd/MM/yyyy').format(value.end)}';

  String _money(num value, {bool signed = false}) {
    final text = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(value.abs());
    if (value < 0) return '−$text';
    return signed && value > 0 ? '+$text' : text;
  }

  DateTimeRange get _previousRange {
    final days = _range.end.difference(_range.start).inDays + 1;
    final end = _range.start.subtract(const Duration(days: 1));
    return DateTimeRange(
      start: end.subtract(Duration(days: days - 1)),
      end: end,
    );
  }

  Future<void> _pickDateRange() async {
    final value = await showCustomDateRangePicker(
      context,
      initialRange: _range,
    );
    if (value != null) setState(() => _range = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final currentKey = (from: _key(_range.start), to: _key(_range.end));
    final previous = _previousRange;
    final previousKey = (from: _key(previous.start), to: _key(previous.end));
    final currentAsync = ref.watch(profitLossProvider(currentKey));
    final previousAsync = ref.watch(profitLossProvider(previousKey));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: context.canPop() ? 60 : null,
        leading: context.canPop()
            ? AppNavigationBackLeading(onPressed: context.pop)
            : null,
        title: const Text('Kết quả kinh doanh'),
        centerTitle: true,
        actions: [featureGuideButton(context, 'profit_loss')],
      ),
      body: currentAsync.when(
        loading: () => const _ReportLoading(),
        error: (_, _) => AppResponsiveContent(
          maxWidth: 1320,
          child: AppInlineError(
            message: 'Không thể tải báo cáo kết quả kinh doanh.',
            onRetry: () => ref.invalidate(profitLossProvider(currentKey)),
          ),
        ),
        data: (data) {
          final current = _Pnl.fromMap(data);
          if (current.isEmpty) {
            return const AppEmpty(
              visual: AppEmptyVisual.finance,
              message: 'Chưa có dữ liệu doanh thu và chi phí trong kỳ',
              subtitle:
                  'Ghi nhận bán hàng và chi phí để lập báo cáo kết quả kinh doanh.',
            );
          }
          return previousAsync.when(
            loading: () => _report(current, null, comparing: true),
            error: (_, _) => _report(current, null, comparisonError: true),
            data: (value) => _report(current, _Pnl.fromMap(value)),
          );
        },
      ),
    );
  }

  Widget _report(
    _Pnl current,
    _Pnl? previous, {
    bool comparing = false,
    bool comparisonError = false,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: AppResponsiveContent(
        maxWidth: 1320,
        verticalPadding: AppSpacing.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReportHeading(
              currentPeriod: _period(_range),
              previousPeriod: _period(_previousRange),
              onChange: _pickDateRange,
            ),
            if (comparisonError) ...[
              const SizedBox(height: 8),
              AppInlineError(
                message:
                    'Không tải được kỳ trước. Số liệu kỳ hiện tại vẫn được giữ nguyên.',
                onRetry: () => ref.invalidate(
                  profitLossProvider((
                    from: _key(_previousRange.start),
                    to: _key(_previousRange.end),
                  )),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppFillGrid(
              minItemWidth: 220,
              maxColumns: 3,
              itemHeight: 126,
              children: [
                _Metric(
                  title: 'Doanh thu thuần',
                  value: current.revenue,
                  previous: previous?.revenue,
                  loading: comparing,
                  color: AppColors.primary,
                  asset: AppAssets.revenue,
                  formatter: _money,
                ),
                _Metric(
                  title: 'Lợi nhuận gộp',
                  value: current.grossProfit,
                  previous: previous?.grossProfit,
                  loading: comparing,
                  color: current.grossProfit >= 0
                      ? AppColors.success
                      : AppColors.danger,
                  asset: AppAssets.profit,
                  ratio: current.grossMargin,
                  formatter: _money,
                ),
                _Metric(
                  title: current.netProfit >= 0 ? 'Lợi nhuận ròng' : 'Lỗ ròng',
                  value: current.netProfit,
                  previous: previous?.netProfit,
                  loading: comparing,
                  color: current.netProfit >= 0
                      ? AppColors.success
                      : AppColors.danger,
                  asset: AppAssets.profit,
                  ratio: current.netMargin,
                  formatter: _money,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final statement = _Statement(
                  current: current,
                  previous: previous,
                  formatter: _money,
                );
                final calculation = _Calculation(
                  values: current,
                  formatter: _money,
                );
                if (constraints.maxWidth < 980) {
                  return Column(
                    children: [
                      statement,
                      const SizedBox(height: AppSpacing.lg),
                      calculation,
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: statement),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(flex: 4, child: calculation),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            const _AccountingNote(),
          ],
        ),
      ),
    );
  }
}

class _Pnl {
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double expenses;
  final double netProfit;

  const _Pnl({
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
  });

  factory _Pnl.fromMap(Map<String, dynamic> value) => _Pnl(
    revenue: TypeParser.asDouble(value['revenue']),
    cogs: TypeParser.asDouble(value['cogs']),
    grossProfit: TypeParser.asDouble(value['grossProfit']),
    expenses: TypeParser.asDouble(
      value['operatingExpenses'] ?? value['expenses'],
    ),
    netProfit: TypeParser.asDouble(value['netProfit']),
  );

  bool get isEmpty => revenue == 0 && cogs == 0 && expenses == 0;
  double get grossMargin => revenue == 0 ? 0 : grossProfit / revenue * 100;
  double get cogsRatio => revenue == 0 ? 0 : cogs / revenue * 100;
  double get expenseRatio => revenue == 0 ? 0 : expenses / revenue * 100;
  double get netMargin => revenue == 0 ? 0 : netProfit / revenue * 100;
}

class _ReportHeading extends StatelessWidget {
  final String currentPeriod;
  final String previousPeriod;
  final VoidCallback onChange;

  const _ReportHeading({
    required this.currentPeriod,
    required this.previousPeriod,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tổng quan lãi và lỗ',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kỳ này: $currentPeriod  •  So sánh: $previousPeriod',
          style: TextStyle(color: colors.textSecondary, height: 1.4),
        ),
      ],
    );
    final action = OutlinedButton.icon(
      onPressed: onChange,
      icon: const Icon(Icons.calendar_month_rounded, size: 18),
      label: const Text('Đổi kỳ báo cáo'),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 650
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 12), action],
            )
          : Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 16),
                action,
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String title;
  final double value;
  final double? previous;
  final bool loading;
  final Color color;
  final String asset;
  final double? ratio;
  final String Function(num value, {bool signed}) formatter;

  const _Metric({
    required this.title,
    required this.value,
    required this.previous,
    required this.loading,
    required this.color,
    required this.asset,
    required this.formatter,
    this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final difference = previous == null ? null : value - previous!;
    final comparisonColor = difference == null || difference == 0
        ? colors.textSecondary
        : difference > 0
        ? AppColors.success
        : AppColors.danger;
    return AppCardContainer(
      padding: const EdgeInsets.all(16),
      borderColor: color.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAssetIcon(
                assetPath: asset,
                size: 18,
                color: color,
                semanticLabel: title,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (ratio != null)
                Text(
                  '${ratio!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            formatter(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.tabularStyle(
              context,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          if (loading)
            const AppShimmer(child: ShimmerBox(width: 145, height: 13))
          else
            Text(
              difference == null
                  ? 'Chưa có dữ liệu so sánh'
                  : '${formatter(difference, signed: true)} so với kỳ trước',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.tabularStyle(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: comparisonColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _RowData {
  final String label;
  final double current;
  final double? previous;
  final String route;
  final bool deduction;
  final bool total;

  const _RowData({
    required this.label,
    required this.current,
    required this.previous,
    required this.route,
    this.deduction = false,
    this.total = false,
  });
}

class _Statement extends StatelessWidget {
  final _Pnl current;
  final _Pnl? previous;
  final String Function(num value, {bool signed}) formatter;

  const _Statement({
    required this.current,
    required this.previous,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final rows = [
      _RowData(
        label: 'Doanh thu thuần',
        current: current.revenue,
        previous: previous?.revenue,
        route: '/sales',
      ),
      _RowData(
        label: '(−) Giá vốn hàng bán',
        current: current.cogs,
        previous: previous?.cogs,
        route: '/xnt-report',
        deduction: true,
      ),
      _RowData(
        label: 'Lợi nhuận gộp',
        current: current.grossProfit,
        previous: previous?.grossProfit,
        route: '/sales',
        total: true,
      ),
      _RowData(
        label: '(−) Chi phí vận hành',
        current: current.expenses,
        previous: previous?.expenses,
        route: '/expense-ledger',
        deduction: true,
      ),
      _RowData(
        label: current.netProfit >= 0 ? 'Lợi nhuận ròng' : 'Lỗ ròng',
        current: current.netProfit,
        previous: previous?.netProfit,
        route: '/transactions',
        total: true,
      ),
    ];
    return AppCardContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Báo cáo lãi – lỗ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chọn một khoản mục để mở dữ liệu đối soát.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 700
                ? Column(
                    children: rows
                        .map(
                          (row) => _MobileRow(
                            data: row,
                            revenue: current.revenue,
                            formatter: formatter,
                          ),
                        )
                        .toList(),
                  )
                : _StatementTable(
                    rows: rows,
                    revenue: current.revenue,
                    formatter: formatter,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatementTable extends StatelessWidget {
  final List<_RowData> rows;
  final double revenue;
  final String Function(num value, {bool signed}) formatter;

  const _StatementTable({
    required this.rows,
    required this.revenue,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.1),
        1: FlexColumnWidth(1.25),
        2: FlexColumnWidth(1.25),
        3: FlexColumnWidth(1.25),
        4: FlexColumnWidth(.9),
      },
      border: TableBorder(horizontalInside: BorderSide(color: colors.divider)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: colors.surface),
          children: const [
            _Header('Khoản mục', left: true),
            _Header('Kỳ này'),
            _Header('Kỳ trước'),
            _Header('Chênh lệch'),
            _Header('% doanh thu'),
          ],
        ),
        for (final row in rows)
          TableRow(
            decoration: BoxDecoration(
              color: row.total
                  ? (row.current < 0 ? AppColors.danger : AppColors.success)
                        .withValues(alpha: .055)
                  : null,
            ),
            children: [
              _Cell(
                onTap: () => context.push(row.route),
                left: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: row.total
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
              _Money(value: row.current, data: row, formatter: formatter),
              _Money(value: row.previous, data: row, formatter: formatter),
              _Money(
                value: row.previous == null
                    ? null
                    : row.current - row.previous!,
                data: row,
                formatter: formatter,
                signed: true,
                ignoreDeduction: true,
              ),
              _Cell(
                child: Text(
                  revenue == 0
                      ? '—'
                      : '${(row.current / revenue * 100).toStringAsFixed(1)}%',
                  style: AppTheme.tabularStyle(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  final bool left;
  const _Header(this.text, {this.left = false});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: left ? TextAlign.left : TextAlign.right,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final Widget child;
  final bool left;
  final VoidCallback? onTap;
  const _Cell({required this.child, this.left = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 58),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: child,
    );
    return onTap == null
        ? content
        : Semantics(
            button: true,
            hint: 'Mở dữ liệu đối soát',
            child: InkWell(onTap: onTap, child: content),
          );
  }
}

class _Money extends StatelessWidget {
  final double? value;
  final _RowData data;
  final String Function(num value, {bool signed}) formatter;
  final bool signed;
  final bool ignoreDeduction;

  const _Money({
    required this.value,
    required this.data,
    required this.formatter,
    this.signed = false,
    this.ignoreDeduction = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final text = value == null
        ? '—'
        : data.deduction && !ignoreDeduction
        ? '(${formatter(value!)})'
        : formatter(value!, signed: signed);
    final valueColor = value == null
        ? colors.textSecondary
        : signed && value != 0
        ? (data.deduction
              ? (value! < 0 ? AppColors.success : AppColors.danger)
              : (value! > 0 ? AppColors.success : AppColors.danger))
        : value! < 0
        ? AppColors.danger
        : colors.textPrimary;
    return _Cell(
      child: Text(
        text,
        maxLines: 1,
        style: AppTheme.tabularStyle(
          context,
          fontSize: 12,
          fontWeight: data.total ? FontWeight.w800 : FontWeight.w600,
          color: valueColor,
        ),
      ),
    );
  }
}

class _MobileRow extends StatelessWidget {
  final _RowData data;
  final double revenue;
  final String Function(num value, {bool signed}) formatter;

  const _MobileRow({
    required this.data,
    required this.revenue,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final difference = data.previous == null
        ? null
        : data.current - data.previous!;
    return InkWell(
      onTap: () => context.push(data.route),
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: data.total
              ? (data.current < 0 ? AppColors.danger : AppColors.success)
                    .withValues(alpha: .055)
              : null,
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: data.total
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    data.previous == null
                        ? 'Kỳ trước: —'
                        : 'Kỳ trước ${formatter(data.previous!)}  •  '
                              '${formatter(difference!, signed: true)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.tabularStyle(
                      context,
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  data.deduction
                      ? '(${formatter(data.current)})'
                      : formatter(data.current),
                  style: AppTheme.tabularStyle(
                    context,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: data.current < 0
                        ? AppColors.danger
                        : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  revenue == 0
                      ? '—'
                      : '${(data.current / revenue * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _Calculation extends StatelessWidget {
  final _Pnl values;
  final String Function(num value, {bool signed}) formatter;
  const _Calculation({required this.values, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return AppCardContainer(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cầu nối lợi nhuận',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cách doanh thu chuyển thành lợi nhuận trong kỳ',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 14),
          _CalcLine('', 'Doanh thu thuần', formatter(values.revenue)),
          _CalcLine('−', 'Giá vốn hàng bán', formatter(values.cogs)),
          _CalcLine(
            '=',
            'Lợi nhuận gộp',
            formatter(values.grossProfit),
            total: true,
            color: values.grossProfit >= 0
                ? AppColors.success
                : AppColors.danger,
          ),
          _CalcLine('−', 'Chi phí vận hành', formatter(values.expenses)),
          _CalcLine(
            '=',
            values.netProfit >= 0 ? 'Lợi nhuận ròng' : 'Lỗ ròng',
            formatter(values.netProfit),
            total: true,
            color: values.netProfit >= 0 ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(height: 14),
          Text(
            'Hiệu quả trên doanh thu',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _Ratio('Giá vốn', values.cogsRatio),
          _Ratio('Biên lợi nhuận gộp', values.grossMargin),
          _Ratio('Chi phí vận hành', values.expenseRatio),
          _Ratio('Biên lợi nhuận ròng', values.netMargin, highlight: true),
        ],
      ),
    );
  }
}

class _CalcLine extends StatelessWidget {
  final String operator;
  final String label;
  final String value;
  final bool total;
  final Color? color;
  const _CalcLine(
    this.operator,
    this.label,
    this.value, {
    this.total = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final foreground = color ?? colors.textPrimary;
    return Container(
      constraints: const BoxConstraints(minHeight: 49),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              operator,
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: total ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: AppTheme.tabularStyle(
              context,
              fontSize: 13,
              fontWeight: total ? FontWeight.w800 : FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ratio extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;
  const _Ratio(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: colors.textSecondary)),
          ),
          Text(
            '${value.toStringAsFixed(1)}%',
            style: AppTheme.tabularStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: highlight
                  ? (value >= 0 ? AppColors.success : AppColors.danger)
                  : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountingNote extends StatelessWidget {
  const _AccountingNote();
  @override
  Widget build(BuildContext context) {
    final color = AppThemeColors.of(context).textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Số liệu được tổng hợp từ sổ giao dịch trong kỳ. Giá trị trong ngoặc là khoản khấu trừ khỏi lợi nhuận.',
            style: TextStyle(fontSize: 11, color: color, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _ReportLoading extends StatelessWidget {
  const _ReportLoading();
  @override
  Widget build(BuildContext context) {
    return AppResponsiveContent(
      maxWidth: 1320,
      verticalPadding: AppSpacing.lg,
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: 250, height: 28),
            const SizedBox(height: 10),
            const ShimmerBox(width: 420, height: 14),
            const SizedBox(height: 24),
            Row(
              children: [
                for (var index = 0; index < 3; index++) ...[
                  const Expanded(child: ShimmerBox(width: 280, height: 126)),
                  if (index < 2) const SizedBox(width: 16),
                ],
              ],
            ),
            const SizedBox(height: 20),
            const ShimmerBox(width: double.infinity, height: 390),
          ],
        ),
      ),
    );
  }
}
