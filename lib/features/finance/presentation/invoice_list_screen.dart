import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/responsive_layout.dart';
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
    final compactLayout = MediaQuery.sizeOf(context).width < 720;
    final canEdit = ref.watch(shopProvider).hasPermission('finance', 'edit');

    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: compactLayout || !canEdit
          ? null
          : AppPrimaryFloatingAction(
              label: 'Thêm hóa đơn',
              assetPath: AppAssets.add,
              heroTag: 'invoice-add-action',
              onPressed: () => _showAddDialog(context, ref),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Hóa đơn'),
        actions: [
          featureGuideButton(context, 'invoices'),
          if (compactLayout && canEdit)
            AppPrimaryHeaderAction(
              label: 'Thêm hóa đơn',
              assetPath: AppAssets.add,
              heroTag: 'invoice-add-action-compact',
              onPressed: () => _showAddDialog(context, ref),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: invAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          final currentPage = paginationValue(data, 'page', fallback: _page);
          final totalPages = paginationValue(data, 'totalPages', fallback: 1);
          final totalItems = paginationValue(
            data,
            'total',
            fallback: items.length,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: 16, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Legal Disclaimer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tính năng lưu trữ số hóa Hóa đơn điện tử nội bộ. Ứng dụng không tự phát hành hóa đơn GTGT.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: c.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Các số VAT dưới đây chỉ dùng để đối chiếu dữ liệu hóa đơn, không thay thế nghĩa vụ thuế trên tờ khai.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Summary Metrics - Taste-Skill: Left-aligned, no heavy cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    final vatIn = asNum(summary['vatIn']);
                    final vatOut = asNum(summary['vatOut']);
                    final vatOwed = asNum(summary['vatOwed']);
                    final vatCredit = asNum(summary['vatCredit']);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AppFillGrid(
                        minItemWidth: 180,
                        maxColumns: 3,
                        itemHeight: 92,
                        children: [
                          _buildMetricItem(
                            'VAT đầu vào',
                            _fmt(vatIn),
                            AppColors.success,
                            c,
                            theme,
                          ),
                          _buildMetricItem(
                            'VAT đầu ra',
                            _fmt(vatOut),
                            AppColors.danger,
                            c,
                            theme,
                          ),
                          _buildMetricItem(
                            vatOwed > 0
                                ? 'Chênh lệch đầu ra − đầu vào'
                                : 'Chênh lệch đầu vào − đầu ra',
                            _fmt(vatOwed > 0 ? vatOwed : vatCredit),
                            vatOwed > 0 ? AppColors.danger : AppColors.success,
                            c,
                            theme,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: reconciliationAsync.when(
                    loading: () => const _InvoiceQualityLoading(),
                    error: (_, _) => const _InvoiceQualityUnavailable(),
                    data: (response) {
                      final firstDate = DateTime.tryParse(
                        response['from']?.toString() ?? '',
                      );
                      final lastDate = DateTime.tryParse(
                        response['to']?.toString() ?? '',
                      );
                      final qualityPeriodLabel =
                          firstDate != null && lastDate != null
                          ? reportingCompactRangeLabel(firstDate, lastDate)
                          : 'Toàn bộ dữ liệu';
                      return _InvoiceQualityPanel(
                        quality: InvoiceDataQuality.fromResponse(response),
                        periodLabel: qualityPeriodLabel,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // List header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _showAllPeriods
                            ? 'Danh sách hóa đơn · Toàn bộ'
                            : 'Danh sách hóa đơn · $periodLabel',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        '$totalItems bản ghi',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            icon: const Icon(Icons.receipt),
                            label: const Text('Thêm hóa đơn'),
                            onPressed: () => _showAddDialog(context, ref),
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
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: c.divider),
                      itemBuilder: (_, i) {
                        final inv = Map<String, dynamic>.from(items[i] as Map);
                        return _InvoiceTile(
                          invoice: inv,
                          formatter: _fmt,
                          onEdit: !canEdit || invoiceIsLinked(inv)
                              ? null
                              : () => _showEditDialog(context, ref, inv),
                          onDelete: !canEdit || invoiceIsLinked(inv)
                              ? null
                              : () => _confirmDelete(context, ref, inv['id']),
                        );
                      },
                    ),
                  ),
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppPaginationBar(
                      currentPage: currentPage,
                      totalPages: totalPages,
                      totalItems: totalItems,
                      itemLabel: 'hóa đơn',
                      onPageChanged: (page) => setState(() => _page = page),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    Color valueColor,
    AppThemeColors c,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic id) {
    final invId = id is int ? id : int.tryParse(id?.toString() ?? '0') ?? 0;
    AppConfirmModal.show(
      context,
      title: 'Xóa hóa đơn',
      message:
          'Bạn có chắc chắn muốn xóa hóa đơn này? Mọi dữ liệu liên quan sẽ không thể khôi phục.',
      confirmText: 'Xóa',
      cancelText: 'Hủy',
    ).then((confirm) async {
      if (confirm == true) {
        try {
          await ref.read(financeRepoProvider).deleteInvoice(invId);
          ToastService.showSuccess('Xóa hóa đơn thành công');
          ref.invalidate(invoiceListProvider);
          ref.invalidate(invoiceSummaryProvider);
          ref.invalidate(invoiceReconciliationProvider);
        } catch (e) {
          ToastService.showError('Lỗi: $e');
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bộ lọc danh sách',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Chỉ áp dụng cho các hóa đơn bên dưới; KPI VAT vẫn theo $periodLabel.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: AppAssetIcon(
              assetPath: AppAssets.emptyDocument,
              size: 22,
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
                      ? 'Dữ liệu hóa đơn đã cân bằng'
                      : 'Chưa có hóa đơn trong kỳ để xác minh',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đã kiểm tra ${quality.checkedInvoices} hóa đơn · $periodLabel',
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
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _InvoiceTile({
    required this.invoice,
    required this.formatter,
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

    Widget menu() => onEdit == null || onDelete == null
        ? Tooltip(
            message: 'Hóa đơn được quản lý từ chứng từ gốc',
            child: Icon(Icons.lock_outline, color: colors.textMuted, size: 20),
          )
        : PopupMenuButton<String>(
            tooltip: 'Thao tác hóa đơn',
            onSelected: (value) => value == 'edit' ? onEdit!() : onDelete!(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
              PopupMenuItem(value: 'delete', child: Text('Xóa hóa đơn')),
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

    return LayoutBuilder(
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
    );
  }
}
