import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/finance_provider.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  int _page = 1;
  String? _type;

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final invAsync = ref.watch(invoiceListProvider((page: _page, type: _type)));
    final now = DateTime.now();
    final from = DateTime(
      now.year,
      now.month,
      1,
    ).toIso8601String().split('T').first;
    final to = now.toIso8601String().split('T').first;
    final summaryAsync = ref.watch(
      invoiceSummaryProvider((from: from, to: to)),
    );
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final compactLayout = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: compactLayout
          ? null
          : AppPrimaryFloatingAction(
              label: 'Thêm hóa đơn',
              assetPath: AppAssets.add,
              heroTag: 'invoice-add-action',
              onPressed: () => _showAddDialog(context, ref),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      appBar: AppBar(
        title: const Text('Hóa đơn'),
        actions: [
          featureGuideButton(context, 'invoices'),
          if (compactLayout)
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

                // Summary Metrics - Taste-Skill: Left-aligned, no heavy cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Thuế VAT tháng này',
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
                            'Phải nộp',
                            _fmt(vatOwed),
                            vatOwed > 0 ? AppColors.danger : AppColors.success,
                            c,
                            theme,
                          ),
                        ],
                      ),
                    );
                  },
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
                        'Danh sách hóa đơn',
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const <(String?, String)>[
                        (null, 'Tất cả'),
                        ('IN', 'Đầu vào'),
                        ('OUT', 'Đầu ra'),
                      ])
                        ChoiceChip(
                          label: Text(option.$2),
                          selected: _type == option.$1,
                          onSelected: (_) => setState(() {
                            _type = option.$1;
                            _page = 1;
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (items.isEmpty)
                  AppEmpty(
                    visual: AppEmptyVisual.document,
                    message: 'Chưa có hóa đơn nào',
                    action: ElevatedButton.icon(
                      icon: const Icon(Icons.receipt),
                      label: const Text('Thêm hóa đơn'),
                      onPressed: () => _showAddDialog(context, ref),
                    ),
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
                          onEdit: () => _showEditDialog(context, ref, inv),
                          onDelete: () =>
                              _confirmDelete(context, ref, inv['id']),
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
    final numC = TextEditingController();
    final partnerC = TextEditingController();
    final amountC = TextEditingController();
    final vatC = TextEditingController();
    String type = 'IN';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm hóa đơn'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'IN', child: Text('Đầu vào')),
                  DropdownMenuItem(value: 'OUT', child: Text('Đầu ra')),
                ],
                onChanged: (v) => type = v ?? 'IN',
                decoration: const InputDecoration(labelText: 'Loại'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: numC,
                decoration: const InputDecoration(labelText: 'Số hóa đơn'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: partnerC,
                decoration: const InputDecoration(labelText: 'Đối tác'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountC,
                decoration: const InputDecoration(
                  labelText: 'Số tiền trước thuế',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: vatC,
                decoration: const InputDecoration(labelText: 'Tiền VAT'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final partnerName = partnerC.text.trim();
              final subtotal = double.tryParse(amountC.text) ?? 0;
              final taxAmount = double.tryParse(vatC.text) ?? 0;
              if (partnerName.isEmpty || subtotal <= 0 || taxAmount < 0) {
                ToastService.showError(
                  'Vui lòng nhập đối tác, số tiền > 0 và VAT hợp lệ',
                );
                return;
              }
              await ref.read(financeRepoProvider).createInvoice({
                'invoiceType': type,
                'invoiceNumber': numC.text.trim().isEmpty
                    ? null
                    : numC.text.trim(),
                'partnerName': partnerName,
                'subtotal': subtotal,
                'taxAmount': taxAmount,
                'totalAmount': subtotal + taxAmount,
                'invoiceDate': DateTime.now()
                    .toIso8601String()
                    .split('T')
                    .first,
              });
              ref.invalidate(invoiceListProvider);
              ref.invalidate(invoiceSummaryProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, dynamic inv) {
    final invId = inv['id'] is int
        ? inv['id']
        : int.tryParse(inv['id']?.toString() ?? '0') ?? 0;
    final numC = TextEditingController(text: inv['invoiceNumber']?.toString());
    final partnerC = TextEditingController(
      text: inv['partnerName']?.toString(),
    );
    final amountC = TextEditingController(text: inv['subtotal']?.toString());
    final vatC = TextEditingController(text: inv['taxAmount']?.toString());
    String type = inv['invoiceType']?.toString() ?? 'IN';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa hóa đơn'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'IN', child: Text('Đầu vào')),
                  DropdownMenuItem(value: 'OUT', child: Text('Đầu ra')),
                ],
                onChanged: (v) => type = v ?? 'IN',
                decoration: const InputDecoration(labelText: 'Loại'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: numC,
                decoration: const InputDecoration(labelText: 'Số hóa đơn'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: partnerC,
                decoration: const InputDecoration(labelText: 'Đối tác'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountC,
                decoration: const InputDecoration(
                  labelText: 'Số tiền trước thuế',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: vatC,
                decoration: const InputDecoration(labelText: 'Tiền VAT'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final partnerName = partnerC.text.trim();
              final subtotal = double.tryParse(amountC.text) ?? 0;
              final taxAmount = double.tryParse(vatC.text) ?? 0;
              if (partnerName.isEmpty || subtotal <= 0 || taxAmount < 0) {
                ToastService.showError(
                  'Vui lòng nhập đối tác, số tiền > 0 và VAT hợp lệ',
                );
                return;
              }
              await ref.read(financeRepoProvider).updateInvoice(invId, {
                'invoiceType': type,
                'invoiceNumber': numC.text.trim().isEmpty
                    ? null
                    : numC.text.trim(),
                'partnerName': partnerName,
                'subtotal': subtotal,
                'taxAmount': taxAmount,
                'totalAmount': subtotal + taxAmount,
              });
              ref.invalidate(invoiceListProvider);
              ref.invalidate(invoiceSummaryProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Cập nhật'),
          ),
        ],
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
        } catch (e) {
          ToastService.showError('Lỗi: $e');
        }
      }
    });
  }
}

class _InvoiceTile extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final String Function(num value) formatter;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
    final tax = asNum(invoice['taxAmount']);

    Widget menu() => PopupMenuButton<String>(
      tooltip: 'Thao tác hóa đơn',
      onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
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
                          'VAT ${formatter(tax)}',
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
                      'VAT ${formatter(tax)}',
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
