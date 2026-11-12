import '../../../core/assets/app_icon.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_page_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../settings/providers/shop_provider.dart';
import '../domain/invoice_data_quality.dart';
import '../providers/finance_provider.dart';
import 'invoice_editor_dialog.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  int _page = 1;
  String? _type;
  bool _showAllPeriods = false;

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final period = currentMonthReportingPeriod(DateTime.now());
    final from = period.from;
    final to = period.to;
    final listPeriod = invoiceListPeriodParams(
      showAll: _showAllPeriods,
      from: from,
      to: to,
    );
    final invAsync = ref.watch(
      invoiceListProvider((
        page: _page,
        type: _type,
        from: listPeriod.from,
        to: listPeriod.to,
      )),
    );
    final periodLabel = reportingCompactRangeLabel(
      DateTime.parse(from),
      DateTime.parse(to),
    );
    final summaryAsync = ref.watch(
      invoiceSummaryProvider((from: from, to: to)),
    );
    final reconciliationAsync = ref.watch(
      invoiceReconciliationProvider((from: null, to: null, all: true)),
    );
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final canEdit = ref.watch(shopProvider).hasPermission('finance', 'edit');

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppPageHeader(
                title: 'Hóa đơn',
                showBackButton: true,
                dense: true,
                titleStyle: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                action: Wrap(
                  spacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    featureGuideButton(context, 'invoices'),
                    if (canEdit)
                      AppPrimaryPageAction(
                        label: 'Thêm hóa đơn',
                        assetPath: AppAssets.add,
                        onPressed: () => _showAddDialog(context, ref),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: invAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppInlineError(
                      message:
                          'Không thể tải danh sách hóa đơn. Vui lòng thử lại sau.',
                      onRetry: () async {
                        ref.invalidate(invoiceListProvider);
                        ref.invalidate(invoiceSummaryProvider);
                        ref.invalidate(invoiceReconciliationProvider);
                      },
                    ),
                  ),
                ),
                data: (data) {
                  final items = (data['items'] as List?) ?? [];
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
                  final totalItems = paginationValue(
                    data,
                    'total',
                    fallback: items.length,
                  );

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(invoiceListProvider);
                      ref.invalidate(invoiceSummaryProvider);
                      ref.invalidate(invoiceReconciliationProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Hóa đơn nội bộ. Chọn một dòng để xem chi tiết.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: c.textSecondary),
                                      ),
                                    ),
                                    IconButton(
                                      key: const Key('invoice-scope-button'),
                                      tooltip: 'Phạm vi sử dụng hóa đơn',
                                      onPressed: () =>
                                          _showScopeDialog(context),
                                      icon: const AppIcon(
                                        Icons.info_outline_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Summary Metrics - Taste-Skill: Left-aligned, no heavy cards
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'Đối chiếu VAT · $periodLabel',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              summaryAsync.when(
                                loading: () => const LinearProgressIndicator(),
                                error: (_, _) => const SizedBox(),
                                data: (summary) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: _InvoiceVatSummary(summary: summary),
                                  );
                                },
                              ),

                              const SizedBox(height: 12),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: reconciliationAsync.when(
                                  loading: () => const _InvoiceQualityLoading(),
                                  error: (_, _) =>
                                      const _InvoiceQualityUnavailable(),
                                  data: (response) {
                                    final firstDate = DateTime.tryParse(
                                      response['from']?.toString() ?? '',
                                    );
                                    final lastDate = DateTime.tryParse(
                                      response['to']?.toString() ?? '',
                                    );
                                    final qualityPeriodLabel =
                                        firstDate != null && lastDate != null
                                        ? reportingCompactRangeLabel(
                                            firstDate,
                                            lastDate,
                                          )
                                        : 'Toàn bộ dữ liệu';
                                    return _InvoiceQualityPanel(
                                      quality: InvoiceDataQuality.fromResponse(
                                        response,
                                      ),
                                      periodLabel: qualityPeriodLabel,
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              // List header
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _showAllPeriods
                                            ? 'Danh sách hóa đơn · Toàn bộ'
                                            : 'Danh sách hóa đơn · $periodLabel',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: c.textPrimary,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '$totalItems bản ghi',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: c.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: InvoiceListFilters(
                                  periodLabel: periodLabel,
                                  showAllPeriods: _showAllPeriods,
                                  type: _type,
                                  onPeriodChanged: (showAll) => setState(() {
                                    _showAllPeriods = showAll;
                                    _page = 1;
                                  }),
                                  onTypeChanged: (type) => setState(() {
                                    _type = type;
                                    _page = 1;
                                  }),
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (items.isEmpty)
                                AppEmpty(
                                  visual: AppEmptyVisual.document,
                                  message: _showAllPeriods
                                      ? 'Chưa có hóa đơn nào'
                                      : 'Chưa có hóa đơn trong $periodLabel',
                                  subtitle: _showAllPeriods
                                      ? null
                                      : 'Chuyển sang “Toàn bộ thời gian” để xem dữ liệu các kỳ trước.',
                                  action: canEdit
                                      ? ElevatedButton.icon(
                                          icon: const AppIcon(Icons.receipt),
                                          label: const Text('Thêm hóa đơn'),
                                          onPressed: () =>
                                              _showAddDialog(context, ref),
                                        )
                                      : null,
                                )
                              else
                                // Taste-Skill: Flat List
                                Container(
                                  decoration: BoxDecoration(
                                    color: c.card,
                                    border: Border(
                                      top: BorderSide(
                                        color: c.divider.withValues(alpha: 0.5),
                                      ),
                                      bottom: BorderSide(
                                        color: c.divider.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: items.length,
                                    separatorBuilder: (_, _) =>
                                        Divider(height: 1, color: c.divider),
                                    itemBuilder: (_, i) {
                                      final inv = Map<String, dynamic>.from(
                                        items[i] as Map,
                                      );
                                      return _InvoiceTile(
                                        invoice: inv,
                                        formatter: _fmt,
                                        onView: () => _showInvoiceDetails(
                                          context,
                                          ref,
                                          inv,
                                        ),
                                        onEdit: !canEdit || invoiceIsLinked(inv)
                                            ? null
                                            : () => _showEditDialog(
                                                context,
                                                ref,
                                                inv,
                                              ),
                                        onDelete:
                                            !canEdit || invoiceIsLinked(inv)
                                            ? null
                                            : () => _confirmDelete(
                                                context,
                                                ref,
                                                inv,
                                              ),
                                      );
                                    },
                                  ),
                                ),
                              if (items.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: AppPaginationBar(
                                    currentPage: currentPage,
                                    totalPages: totalPages,
                                    totalItems: totalItems,
                                    itemLabel: 'hóa đơn',
                                    onPageChanged: (page) =>
                                        setState(() => _page = page),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScopeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Phạm vi dữ liệu hóa đơn'),
        scrollable: true,
        content: const Text(
          'Tính năng lưu trữ số hóa Hóa đơn điện tử nội bộ. Ứng dụng không tự phát hành hóa đơn GTGT.\n\n'
          'VAT được cộng từ tiền thuế ghi trên hóa đơn trong kỳ. Hóa đơn có giá trị hàng vẫn có thể ghi VAT 0 đ. '
          'Bộ lọc danh sách không thay đổi kỳ tổng hợp VAT.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => InvoiceEditorDialog(
        onSubmit: (payload) async {
          await ref.read(financeRepoProvider).createInvoice(payload);
          ref.invalidate(invoiceListProvider);
          ref.invalidate(invoiceSummaryProvider);
          ref.invalidate(invoiceReconciliationProvider);
          ToastService.showSuccess('Đã thêm hóa đơn');
        },
      ),
    );
  }

  void _showInvoiceDetails(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> invoice,
  ) {
    final id = int.tryParse(invoice['id'].toString());
    if (id == null || id <= 0) return;
    final detail = ref.read(financeRepoProvider).findInvoiceById(id);
    showDialog<void>(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: detail,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final lines = (data?['items'] as List?)?.whereType<Map>() ?? const [];
          final linked = invoiceIsLinked(invoice);
          final referenceId = int.tryParse(
            data?['referenceId'].toString() ?? '',
          );
          final sourceRoute = referenceId == null || referenceId <= 0
              ? null
              : switch (data?['referenceType']) {
                  'SALES_ORDER' => '/sales/$referenceId',
                  'PURCHASE_ORDER' => '/purchase-orders/detail?id=$referenceId',
                  'CASH_TRANSACTION' => '/transactions/$referenceId',
                  _ => null,
                };
          return AlertDialog(
            title: Text('Hóa đơn ${invoice['invoiceNumber'] ?? ''}'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: snapshot.hasError
                    ? const Text(
                        'Không tải được chi tiết. Vui lòng mở lại hóa đơn.',
                      )
                    : data == null
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Đối tác: ${data['partnerName'] ?? 'Chưa ghi'}'),
                          Text(
                            'Ngày: ${data['invoiceDate']?.toString().split('T').first ?? 'Chưa ghi'}',
                          ),
                          Text(
                            'Tổng tiền: ${_fmt(asNum(data['totalAmount']))}',
                          ),
                          Text(
                            'VAT ghi trên hóa đơn: ${_fmt(asNum(data['taxAmount']))}',
                          ),
                          if (linked)
                            Text(
                              'Nguồn: ${data['referenceType']} #${data['referenceId']}. Điều chỉnh tại chứng từ gốc.',
                            ),
                          const Divider(),
                          if (lines.isEmpty)
                            const Text('Hóa đơn chưa có dòng hàng.'),
                          for (final line in lines)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                (line['productName'] ??
                                        line['description'] ??
                                        (line['product'] is Map
                                            ? line['product']['name']
                                            : null) ??
                                        'Dòng hàng')
                                    .toString(),
                              ),
                              subtitle: Text(
                                'Số lượng: ${line['quantity'] ?? '—'} · Đơn giá: ${_fmt(asNum(line['unitPrice']))}',
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            actions: [
              if (sourceRoute != null)
                TextButton(
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.pop(context);
                    router.push(sourceRoute);
                  },
                  child: const Text('Mở chứng từ gốc'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, dynamic inv) {
    final invId = inv['id'] is int
        ? inv['id']
        : int.tryParse(inv['id']?.toString() ?? '0') ?? 0;
    final detailFuture = ref.read(financeRepoProvider).findInvoiceById(invId);
    showDialog(
      context: context,
      builder: (_) => FutureBuilder<Map<String, dynamic>>(
        future: detailFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AlertDialog(
              title: const Text('Không thể mở hóa đơn'),
              content: const Text('Không tải được chi tiết dòng hàng.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const AlertDialog(
              content: SizedBox(
                width: 280,
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return InvoiceEditorDialog(
            initialInvoice: snapshot.data!,
            onSubmit: (payload) async {
              await ref.read(financeRepoProvider).updateInvoice(invId, payload);
              ref.invalidate(invoiceListProvider);
              ref.invalidate(invoiceSummaryProvider);
              ref.invalidate(invoiceReconciliationProvider);
              ToastService.showSuccess('Đã cập nhật hóa đơn');
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> inv,
  ) {
    final invId = inv['id'] is int
        ? inv['id']
        : int.tryParse(inv['id']?.toString() ?? '0') ?? 0;
    final invoiceNumber = inv['invoiceNumber']?.toString();
    final displayCode = (invoiceNumber != null && invoiceNumber.isNotEmpty)
        ? invoiceNumber
        : 'ID $invId';
    final partnerName = inv['partnerName']?.toString() ?? '';
    final dateStr = inv['invoiceDate']?.toString() ?? '';
    String dateLabel = dateStr;
    if (dateStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(dateStr).toLocal();
        dateLabel = DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {}
    }

    final recordInfo = [
      displayCode,
      if (partnerName.isNotEmpty) partnerName,
      if (dateLabel.isNotEmpty) dateLabel,
    ].join(' - ');

    AppConfirmModal.show(
      context,
      title: 'Xóa hóa đơn',
      message:
          'Bạn có chắc chắn muốn xóa hóa đơn "$recordInfo"? Thao tác này sẽ xóa hóa đơn và các dòng chi tiết đi kèm; không hủy các giao dịch mua/bán gốc.',
      confirmText: 'Xóa hóa đơn',
      cancelText: 'Hủy',
      isDestructive: true,
    ).then((confirm) async {
      if (confirm == true) {
        try {
          await ref.read(financeRepoProvider).deleteInvoice(invId);
          ToastService.showSuccess('Xóa hóa đơn thành công');
          ref.invalidate(invoiceListProvider);
          ref.invalidate(invoiceSummaryProvider);
          ref.invalidate(invoiceReconciliationProvider);
        } catch (e) {
          ToastService.showError(
            'Không thể xóa hóa đơn. Vui lòng thử lại sau.',
          );
        }
      }
    });
  }
}

({String? from, String? to}) invoiceListPeriodParams({
  required bool showAll,
  required String from,
  required String to,
}) => showAll ? (from: null, to: null) : (from: from, to: to);

class _InvoiceVatSummary extends StatelessWidget {
  const _InvoiceVatSummary({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final owed = asNum(summary['vatOwed']);
    final format = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final metrics = [
      (
        label: 'VAT đầu vào',
        value: asNum(summary['vatIn']),
        color: colors.textPrimary,
      ),
      (
        label: 'VAT đầu ra',
        value: asNum(summary['vatOut']),
        color: colors.textPrimary,
      ),
      (
        label: owed > 0
            ? 'Chênh lệch đầu ra − đầu vào'
            : 'Chênh lệch đầu vào − đầu ra',
        value: owed > 0 ? owed : asNum(summary['vatCredit']),
        color: owed > 0 ? AppColors.danger : colors.primary,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
        final wide = constraints.maxWidth >= 600 && !largeText;
        Widget cell(int index) {
          final metric = metrics[index];
          final label = Text(
            metric.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          );
          final value = Text(
            format.format(metric.value),
            textAlign: wide || largeText ? TextAlign.start : TextAlign.end,
            style: theme.textTheme.titleSmall?.copyWith(
              color: metric.color,
              fontWeight: FontWeight.w700,
            ),
          );
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 16 : 12,
              vertical: wide ? 14 : 8,
            ),
            child: wide || largeText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [label, const SizedBox(height: 4), value],
                  )
                : Row(
                    children: [
                      Expanded(flex: 3, child: label),
                      const SizedBox(width: 12),
                      Flexible(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: value,
                        ),
                      ),
                    ],
                  ),
          );
        }

        return Container(
          key: const Key('invoice-vat-summary'),
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.divider),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < metrics.length; i++) ...[
                        if (i > 0)
                          VerticalDivider(width: 1, color: colors.divider),
                        Expanded(child: cell(i)),
                      ],
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: colors.divider),
                      cell(i),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class InvoiceListFilters extends StatelessWidget {
  final String periodLabel;
  final bool showAllPeriods;
  final String? type;
  final ValueChanged<bool> onPeriodChanged;
  final ValueChanged<String?> onTypeChanged;
  const InvoiceListFilters({
    super.key,
    required this.periodLabel,
    required this.showAllPeriods,
    required this.type,
    required this.onPeriodChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final periodFilters = Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          label: const Text('Kỳ hiện tại'),
          selected: !showAllPeriods,
          onSelected: (_) => onPeriodChanged(false),
        ),
        ChoiceChip(
          label: const Text('Toàn bộ thời gian'),
          selected: showAllPeriods,
          onSelected: (_) => onPeriodChanged(true),
        ),
      ],
    );
    final typeFilters = Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final option in const <(String?, String)>[
          (null, 'Tất cả loại'),
          ('IN', 'Đầu vào'),
          ('OUT', 'Đầu ra'),
        ])
          ChoiceChip(
            label: Text(option.$2),
            selected: type == option.$1,
            onSelected: (_) => onTypeChanged(option.$1),
          ),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chỉ áp dụng cho các hóa đơn bên dưới; KPI VAT vẫn theo $periodLabel.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 680 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.2) {
                return Row(
                  children: [
                    periodFilters,
                    const SizedBox(width: 20),
                    Container(width: 1, height: 24, color: colors.divider),
                    const SizedBox(width: 20),
                    typeFilters,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  periodFilters,
                  const SizedBox(height: 4),
                  typeFilters,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InvoiceQualityPanel extends StatelessWidget {
  final InvoiceDataQuality quality;
  final String periodLabel;

  const _InvoiceQualityPanel({
    required this.quality,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final hasData = quality.checkedInvoices > 0;
    final accent = quality.hasIssues
        ? AppColors.warning
        : hasData
        ? AppColors.success
        : AppColors.info;
    final details = <String>[
      if (quality.missingItemInvoices > 0)
        '${quality.missingItemInvoices} hóa đơn thiếu dòng chi tiết',
      if (quality.headerTotalMismatchInvoices > 0)
        '${quality.headerTotalMismatchInvoices} hóa đơn lệch tổng',
      if (quality.headerSubtotalMismatchInvoices > 0)
        '${quality.headerSubtotalMismatchInvoices} hóa đơn lệch tiền hàng với chi tiết',
      if (quality.unallocatedDiscountInvoices > 0)
        '${quality.unallocatedDiscountInvoices} hóa đơn bán chưa phân bổ chiết khấu vào dòng',
      if (quality.headerTaxMismatchInvoices > 0)
        '${quality.headerTaxMismatchInvoices} hóa đơn lệch tiền thuế với chi tiết',
      if (quality.invalidLineItems > 0)
        '${quality.invalidLineItems} dòng có số lượng không hợp lệ',
      if (quality.lineSubtotalMismatchItems > 0)
        '${quality.lineSubtotalMismatchItems} dòng lệch thành tiền',
      if (quality.lineTaxMismatchItems > 0)
        '${quality.lineTaxMismatchItems} dòng lệch tiền thuế',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: AppAssetIcon(
              assetPath: AppAssets.emptyDocument,
              size: 18,
              color: accent,
              semanticLabel: 'Chất lượng dữ liệu hóa đơn',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quality.hasIssues
                      ? 'Cần rà soát dữ liệu hóa đơn'
                      : hasData
                      ? 'Tiền trên hóa đơn khớp với các dòng hàng'
                      : 'Chưa có hóa đơn trong kỳ để xác minh',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đã đối chiếu ${quality.checkedInvoices} hóa đơn · $periodLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: details
                        .map(
                          (label) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(
                                AppRadius.control,
                              ),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Không dùng các hóa đơn này để chốt báo cáo trước khi rà soát chứng từ gốc.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceQualityLoading extends StatelessWidget {
  const _InvoiceQualityLoading();

  @override
  Widget build(BuildContext context) => const LinearProgressIndicator();
}

class _InvoiceQualityUnavailable extends StatelessWidget {
  const _InvoiceQualityUnavailable();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(
        'Chưa thể xác minh chất lượng dữ liệu hóa đơn. Vui lòng tải lại trước khi chốt báo cáo.',
        style: TextStyle(color: colors.textSecondary),
      ),
    );
  }
}

bool invoiceIsLinked(Map<String, dynamic> invoice) {
  final referenceType = invoice['referenceType']?.toString().trim();
  return referenceType != null && referenceType.isNotEmpty;
}

class _InvoiceTile extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final String Function(num value) formatter;
  final VoidCallback onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _InvoiceTile({
    required this.invoice,
    required this.formatter,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final isOut = invoice['invoiceType'] == 'OUT';
    final accent = isOut ? AppColors.danger : AppColors.success;
    final number = invoice['invoiceNumber']?.toString().trim();
    final partner = invoice['partnerName']?.toString().trim();
    final date = invoice['invoiceDate']?.toString().split('T').first ?? '';
    final total = asNum(invoice['totalAmount']);
    final discount = asNum(invoice['discountAmount']);
    final tax = asNum(invoice['taxAmount']);
    final detailLabel = discount > 0
        ? 'Giảm ${formatter(discount)} • VAT ${formatter(tax)}'
        : 'VAT ${formatter(tax)}';

    Widget menu() => PopupMenuButton<String>(
      tooltip: 'Thao tác hóa đơn',
      onSelected: (value) {
        if (value == 'view') onView();
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'view', child: Text('Xem chi tiết')),
        if (onEdit != null)
          const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
        if (onDelete != null)
          const PopupMenuItem(value: 'delete', child: Text('Xóa hóa đơn')),
      ],
    );

    Widget typeBadge() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOut ? 'Đầu ra' : 'Đầu vào',
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return InkWell(
      onTap: onView,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          if (compact) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accent, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      typeBadge(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          number?.isNotEmpty == true ? number! : 'Chưa cấp số',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      menu(),
                    ],
                  ),
                  Text(
                    partner?.isNotEmpty == true ? partner! : 'Chưa có đối tác',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          date,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatter(total),
                            style: AppTheme.tabularStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            detailLabel,
                            style: AppTheme.tabularStyle(
                              context,
                              fontSize: 10,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                typeBadge(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        number?.isNotEmpty == true ? number! : 'Chưa cấp số',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        partner?.isNotEmpty == true
                            ? partner!
                            : 'Chưa có đối tác',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatter(total),
                        style: AppTheme.tabularStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        detailLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 92,
                  child: Text(
                    date,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
                menu(),
              ],
            ),
          );
        },
      ),
    );
  }
}
