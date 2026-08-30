import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/finance_display.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/finance_provider.dart';

final _currency = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final String? initialType;
  final String? initialCategory;

  const TransactionHistoryScreen({
    super.key,
    this.initialType,
    this.initialCategory,
  });

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  int _page = 1;
  late String? _type;
  late String? _category;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final period = currentMonthReportingPeriod(DateTime.now());
    final periodLabel = reportingCompactRangeLabel(
      DateTime.parse(period.from),
      DateTime.parse(period.to),
    );
    final query = (
      page: _page,
      limit: 20,
      type: _type,
      category: _category,
      from: period.from,
      to: period.to,
    );
    final transactions = ref.watch(transactionsProvider(query));

    Future<void> refresh() async {
      ref.invalidate(transactionsProvider(query));
      await ref.read(transactionsProvider(query).future);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: context.canPop() ? 60 : null,
        leading: context.canPop()
            ? AppNavigationBackLeading(onPressed: _goBack)
            : null,
        title: const Text('Giao dịch'),
        actions: [featureGuideButton(context, 'transaction_history')],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: AppResponsiveContent(
            maxWidth: 1180,
            verticalPadding: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPageHeader(
                  title: 'Lịch sử giao dịch',
                  subtitle:
                      'Đối soát các khoản thu, chi và phương thức thanh toán trong kỳ $periodLabel.',
                  dense: true,
                  showBackButton: false,
                ),
                transactions.when(
                  loading: () => _TransactionPanel(
                    type: _type,
                    category: _category,
                    periodLabel: periodLabel,
                    onTypeChanged: _changeType,
                    onCategoryCleared: _clearCategory,
                    child: const _TransactionLoading(),
                  ),
                  error: (_, _) => _TransactionPanel(
                    type: _type,
                    category: _category,
                    periodLabel: periodLabel,
                    onTypeChanged: _changeType,
                    onCategoryCleared: _clearCategory,
                    child: AppInlineError(
                      message: 'Không thể tải danh sách giao dịch.',
                      onRetry: () =>
                          ref.invalidate(transactionsProvider(query)),
                    ),
                  ),
                  data: (data) {
                    final items = (data['items'] as List?) ?? const [];
                    final total = paginationValue(
                      data,
                      'total',
                      fallback: items.length,
                    );
                    final currentPage = paginationValue(
                      data,
                      'page',
                      fallback: _page,
                    );
                    final totalPages = paginationValue(
                      data,
                      'totalPages',
                      fallback: 1,
                    );
                    final filteredAmount = asDouble(
                      data['filteredAmountTotal'],
                    );

                    return _TransactionPanel(
                      type: _type,
                      category: _category,
                      periodLabel: periodLabel,
                      total: total,
                      filteredAmount: _type == null ? null : filteredAmount,
                      onTypeChanged: _changeType,
                      onCategoryCleared: _clearCategory,
                      child: items.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 54),
                              child: AppEmpty(
                                visual: AppEmptyVisual.finance,
                                message: 'Không có giao dịch phù hợp',
                                subtitle:
                                    'Thử chọn một loại giao dịch khác để xem dữ liệu trong kỳ.',
                              ),
                            )
                          : Column(
                              children: [
                                _TransactionListHeader(
                                  total: total,
                                  type: _type,
                                ),
                                for (final item in items)
                                  _TransactionRow(
                                    transaction: Map<dynamic, dynamic>.from(
                                      item as Map,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    16,
                                  ),
                                  child: AppPaginationBar(
                                    currentPage: currentPage,
                                    totalPages: totalPages,
                                    totalItems: total,
                                    itemLabel: 'giao dịch',
                                    onPageChanged: (page) =>
                                        setState(() => _page = page),
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _changeType(String? value) {
    if (_type == value) return;
    setState(() {
      _type = value;
      _page = 1;
    });
  }

  void _clearCategory() {
    if (_category == null) return;
    setState(() {
      _category = null;
      _page = 1;
    });
  }

  void _goBack() {
    if (context.canPop()) context.pop();
  }
}

class _TransactionPanel extends StatelessWidget {
  final String? type;
  final String? category;
  final String periodLabel;
  final int? total;
  final double? filteredAmount;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onCategoryCleared;
  final Widget child;

  const _TransactionPanel({
    required this.type,
    required this.category,
    required this.periodLabel,
    required this.onTypeChanged,
    required this.onCategoryCleared,
    required this.child,
    this.total,
    this.filteredAmount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return AppCardContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final filters = _TypeFilter(
                  selected: type,
                  onChanged: onTypeChanged,
                );
                final summary = _FilterSummary(
                  type: type,
                  category: category,
                  total: total,
                  amount: filteredAmount,
                  periodLabel: periodLabel,
                  onCategoryCleared: onCategoryCleared,
                );
                if (constraints.maxWidth < 720) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [summary, const SizedBox(height: 14), filters],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 20),
                    filters,
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: colors.divider),
          child,
        ],
      ),
    );
  }
}

class _FilterSummary extends StatelessWidget {
  final String? type;
  final String? category;
  final int? total;
  final double? amount;
  final String periodLabel;
  final VoidCallback onCategoryCleared;

  const _FilterSummary({
    required this.type,
    required this.category,
    required this.total,
    required this.amount,
    required this.periodLabel,
    required this.onCategoryCleared,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final title = type == 'INCOME'
        ? 'Các khoản thu'
        : type == 'EXPENSE'
        ? 'Các khoản chi'
        : 'Tất cả giao dịch';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (total != null) ...[
              const SizedBox(width: 9),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.divider),
                ),
                child: Text(
                  '$total',
                  style: AppTheme.tabularStyle(
                    context,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount == null
              ? 'Kỳ $periodLabel'
              : 'Tổng giá trị ${_currency.format(amount)}  •  Kỳ $periodLabel',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.tabularStyle(
            context,
            fontSize: 12,
            color: colors.textSecondary,
          ),
        ),
        if (category != null && category!.isNotEmpty) ...[
          const SizedBox(height: 8),
          InputChip(
            label: Text('Nhóm: ${financeCategoryLabel(category)}'),
            onDeleted: onCategoryCleared,
            deleteIcon: const Icon(Icons.close_rounded, size: 16),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }
}

class _TypeFilter extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _TypeFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String?>(
      segments: const [
        ButtonSegment(
          value: null,
          label: Text('Tất cả', maxLines: 1, softWrap: false),
        ),
        ButtonSegment(
          value: 'INCOME',
          label: Text('Thu', maxLines: 1, softWrap: false),
        ),
        ButtonSegment(
          value: 'EXPENSE',
          label: Text('Chi', maxLines: 1, softWrap: false),
        ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (values) => onChanged(values.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

class _TransactionListHeader extends StatelessWidget {
  final int total;
  final String? type;

  const _TransactionListHeader({required this.total, required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) return const SizedBox.shrink();
        return Container(
          color: colors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            children: [
              const SizedBox(width: 44),
              const SizedBox(width: 14),
              const SizedBox(width: 104, child: _ColumnLabel('Ngày')),
              const Expanded(flex: 3, child: _ColumnLabel('Nội dung')),
              const Expanded(flex: 2, child: _ColumnLabel('Phân loại')),
              const Expanded(flex: 2, child: _ColumnLabel('Thanh toán')),
              SizedBox(
                width: 154,
                child: _ColumnLabel(
                  type == 'EXPENSE' ? 'Số tiền chi' : 'Số tiền',
                  right: true,
                ),
              ),
              const SizedBox(width: 28),
            ],
          ),
        );
      },
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  final String text;
  final bool right;
  const _ColumnLabel(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<dynamic, dynamic> transaction;

  const _TransactionRow({required this.transaction});

  bool get isIncome =>
      transaction['type']?.toString().toUpperCase() == 'INCOME';

  String get dateLabel {
    final raw = financeTransactionDateValue(transaction);
    if (raw == null) return 'Chưa có ngày';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final accent = isIncome ? AppColors.success : AppColors.danger;
    final amount = asDouble(transaction['amount']);
    final description = financeTransactionDescription(transaction);
    final category = financeCategoryLabel(transaction['category']?.toString());
    final payment = financePaymentMethodLabel(
      transaction['paymentMethod']?.toString(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Semantics(
          button: true,
          label:
              '${isIncome ? 'Khoản thu' : 'Khoản chi'} $description, ${_currency.format(amount)}, ngày $dateLabel',
          hint: 'Mở chi tiết giao dịch',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  context.push('/transactions/detail', extra: transaction),
              child: Container(
                constraints: BoxConstraints(minHeight: compact ? 82 : 68),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 18,
                  vertical: compact ? 13 : 10,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.divider)),
                ),
                child: compact
                    ? _MobileTransactionContent(
                        isIncome: isIncome,
                        accent: accent,
                        description: description,
                        category: category,
                        payment: payment,
                        date: dateLabel,
                        amount: amount,
                      )
                    : _DesktopTransactionContent(
                        isIncome: isIncome,
                        accent: accent,
                        description: description,
                        category: category,
                        payment: payment,
                        date: dateLabel,
                        amount: amount,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TransactionMark extends StatelessWidget {
  final bool isIncome;
  final Color color;

  const _TransactionMark({required this.isIncome, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
        size: 19,
        color: color,
      ),
    );
  }
}

class _DesktopTransactionContent extends StatelessWidget {
  final bool isIncome;
  final Color accent;
  final String description;
  final String category;
  final String payment;
  final String date;
  final double amount;

  const _DesktopTransactionContent({
    required this.isIncome,
    required this.accent,
    required this.description,
    required this.category,
    required this.payment,
    required this.date,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      children: [
        _TransactionMark(isIncome: isIncome, color: accent),
        const SizedBox(width: 14),
        SizedBox(
          width: 104,
          child: Text(
            date,
            style: AppTheme.tabularStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            category,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            payment,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        ),
        SizedBox(
          width: 154,
          child: Text(
            '${isIncome ? '+' : '−'}${_currency.format(amount)}',
            textAlign: TextAlign.right,
            style: AppTheme.tabularStyle(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
      ],
    );
  }
}

class _MobileTransactionContent extends StatelessWidget {
  final bool isIncome;
  final Color accent;
  final String description;
  final String category;
  final String payment;
  final String date;
  final double amount;

  const _MobileTransactionContent({
    required this.isIncome,
    required this.accent,
    required this.description,
    required this.category,
    required this.payment,
    required this.date,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      children: [
        _TransactionMark(isIncome: isIncome, color: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$date  •  $category  •  $payment',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${isIncome ? '+' : '−'}${_currency.format(amount)}',
          textAlign: TextAlign.right,
          style: AppTheme.tabularStyle(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
        const SizedBox(width: 2),
        Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: colors.textSecondary,
        ),
      ],
    );
  }
}

class _TransactionLoading extends StatelessWidget {
  const _TransactionLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppShimmer(
        child: Column(
          children: [
            for (var index = 0; index < 7; index++)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                child: Row(
                  children: [
                    ShimmerBox(width: 44, height: 44, radius: 11),
                    SizedBox(width: 14),
                    Expanded(child: ShimmerBox(width: 480, height: 44)),
                    SizedBox(width: 14),
                    ShimmerBox(width: 112, height: 18),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
