import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/providers/reporting_period_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/finance_display.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/utils/excel_export_service.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/custom_date_range_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../../settings/providers/shop_provider.dart';

final _currency = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 2,
)..minimumFractionDigits = 0;

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
  ({int? shopId, bool allShops, String from, String to})? _listScope;
  DateTimeRange? _rangeOverride;
  bool _isExporting = false;
  int _exportScopeVersion = 0;

  ({String from, String to}) _period() {
    final resolved = ref.read(tabResolvedPeriodProvider('finance'));
    return (
      from: (_rangeOverride?.start ?? resolved.currentFrom)
          .toIso8601String()
          .split('T')
          .first,
      to: (_rangeOverride?.end ?? resolved.currentTo)
          .toIso8601String()
          .split('T')
          .first,
    );
  }

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authProvider.select((s) => (s.isLoggedIn, s.user?['id']?.toString())),
      (previous, next) {
        if (previous != next) _exportScopeVersion++;
      },
    );
    ref.listen(shopProvider, (previous, next) {
      if (previous?.currentShopId != next.currentShopId ||
          previous?.isAllShops != next.isAllShops ||
          previous?.hasPermission('finance') != next.hasPermission('finance')) {
        _exportScopeVersion++;
      }
    });
    ref.listen(tabResolvedPeriodProvider('finance'), (previous, next) {
      if (previous?.currentFrom != next.currentFrom ||
          previous?.currentTo != next.currentTo) {
        setState(() {
          _rangeOverride = null;
          _exportScopeVersion++;
        });
      }
    });
    final colors = AppThemeColors.of(context);
    ref.watch(tabResolvedPeriodProvider('finance'));
    final period = _period();
    final shop = ref.watch(shopProvider);
    final listScope = (
      shopId: shop.currentShopId,
      allShops: shop.isAllShops,
      from: period.from,
      to: period.to,
    );
    // Reset before constructing the query: a page from another period/shop
    // must not be requested or shown as an empty result in the new scope.
    if (_listScope != listScope) {
      _listScope = listScope;
      _page = 1;
      _exportScopeVersion++;
    }
    final periodLabel = reportingRangeLabel(
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
        leadingWidth: 60,
        leading: AppNavigationBackLeading(onPressed: _goBack),
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
                  action: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickPeriod,
                        icon: const AppIcon(
                          Icons.date_range_outlined,
                          size: 18,
                        ),
                        label: const Text('Chọn kỳ'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isExporting ||
                                shop.isAllShops ||
                                shop.currentShopId == null ||
                                !shop.hasPermission('finance') ||
                                (transactions.asData?.value['total'] as num? ??
                                        0) ==
                                    0
                            ? null
                            : _exportLedger,
                        icon: const AppIcon(Icons.download_outlined, size: 18),
                        label: Text(_isExporting ? 'Đang xuất…' : 'Xuất Excel'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    shop.isAllShops
                        ? 'Chọn một cửa hàng để xuất sổ thu chi.'
                        : 'Excel gồm toàn bộ giao dịch theo kỳ và bộ lọc, kể cả các trang khác.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
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
      _exportScopeVersion++;
    });
  }

  void _clearCategory() {
    if (_category == null) return;
    setState(() {
      _category = null;
      _page = 1;
      _exportScopeVersion++;
    });
  }

  void _goBack() {
    context.canPop() ? context.pop() : context.go('/finance');
  }

  Future<void> _pickPeriod() async {
    final period = _period();
    final picked = await showCustomDateRangePicker(
      context,
      initialRange: DateTimeRange(
        start: DateTime.parse(period.from),
        end: DateTime.parse(period.to),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _rangeOverride = picked;
      _page = 1;
      _exportScopeVersion++;
    });
  }

  Future<void> _exportLedger() async {
    if (_isExporting) return;
    final shop = ref.read(shopProvider);
    final shopId = shop.currentShopId;
    final actor = ref.read(authProvider).user?['id']?.toString();
    final period = _period();
    final type = _type;
    final category = _category;
    final version = _exportScopeVersion;
    bool current() {
      if (!mounted || version != _exportScopeVersion) return false;
      final auth = ref.read(authProvider);
      final active = ref.read(shopProvider);
      return auth.isLoggedIn &&
          !auth.isOfflineSession &&
          actor != null &&
          auth.user?['id']?.toString() == actor &&
          shopId != null &&
          !active.isAllShops &&
          active.currentShopId == shopId &&
          active.hasPermission('finance') &&
          _period() == period &&
          _type == type &&
          _category == category;
    }

    if (!current()) return;
    setState(() => _isExporting = true);
    try {
      final ledger = await ref
          .read(financeRepoProvider)
          .exportTransactionsInShop(
            shopId!,
            from: period.from,
            to: period.to,
            type: type,
            category: category,
            isCurrentScope: current,
          );
      if (!current()) return;
      final launched = await ExcelExportService.exportCashLedger(
        ledger,
        shopName: shop.currentShopName ?? 'Cửa hàng $shopId',
      );
      if (!current()) return;
      if (launched) {
        ToastService.showSuccess(
          'Đã tạo Excel gồm ${ledger.items.length} giao dịch. Kiểm tra mục tải xuống.',
        );
      } else {
        ToastService.showError('Chưa tải được tệp Excel. Vui lòng thử lại.');
      }
    } catch (_) {
      if (current()) {
        ToastService.showError(
          'Không thể xuất sổ thu chi. Vui lòng làm mới dữ liệu rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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
            deleteIcon: const AppIcon(Icons.close_rounded, size: 16),
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
              onTap: () {
                final rawId = transaction['id'];
                final id = rawId is int
                    ? rawId
                    : int.tryParse(rawId?.toString() ?? '');
                if (id != null) {
                  context.go('/transactions/$id?from=transactions');
                }
              },
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
      child: AppIcon(
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
        AppIcon(Icons.chevron_right_rounded, color: colors.textSecondary),
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
        AppIcon(
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
