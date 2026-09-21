import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/finance_provider.dart';

class TaxObligationScreen extends ConsumerWidget {
  final String? initialStatus;

  const TaxObligationScreen({super.key, this.initialStatus});

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final taxAsync = ref.watch(taxObligationsProvider);
    final compactLayout = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Theo dõi Nghĩa vụ thuế',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'tax_obligations'),
          if (compactLayout)
            AppPrimaryHeaderAction(
              label: 'Khai thuế mới',
              assetPath: AppAssets.add,
              heroTag: 'tax-obligation-add-compact',
              onPressed: () => _showAddDialog(context, ref),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: taxAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 48, color: c.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'Không thể tải dữ liệu nghĩa vụ thuế',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$e',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(taxObligationsProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Thử lại'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            data: (data) {
              final allItems = (data['items'] as List?) ?? [];
              final items = initialStatus == 'pending'
                  ? allItems
                        .where(
                          (item) =>
                              item is Map &&
                              !const {'done', 'paid', 'cancelled'}.contains(
                                item['status']?.toString().toLowerCase(),
                              ),
                        )
                        .toList()
                  : allItems;
              final totalOwed = asNum(data['totalOwed']);

              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(taxObligationsProvider),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 420,
                      child: AppEmpty(
                        visual: AppEmptyVisual.tax,
                        message: 'Chưa phát sinh dữ liệu nghĩa vụ thuế',
                        action: ElevatedButton.icon(
                          icon: const Icon(Icons.account_balance_rounded),
                          label: Text(
                            'Thêm kỳ thuế mới',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _showAddDialog(context, ref),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(taxObligationsProvider),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Glowing Total Owed Header Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              totalOwed > 0
                                  ? AppColors.danger
                                  : AppColors.success,
                              (totalOwed > 0
                                      ? AppColors.danger
                                      : AppColors.success)
                                  .withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (totalOwed > 0
                                          ? AppColors.danger
                                          : AppColors.success)
                                      .withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TỔNG THUẾ CÒN PHẢI NỘP',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _fmt(totalOwed),
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Chi tiết các kỳ thuế',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ...items.map<Widget>((t) {
                        final id = t['id'] as int?;
                        final status = t['status'] ?? 'pending';
                        final statusColor = status == 'done'
                            ? AppColors.success
                            : status == 'overdue'
                            ? AppColors.danger
                            : AppColors.warning;
                        final statusLabel = status == 'done'
                            ? 'Hoàn thành'
                            : status == 'overdue'
                            ? 'Quá hạn'
                            : status == 'partial'
                            ? 'Một phần'
                            : 'Chờ nộp';
                        final vatDeclared = asNum(t['vatDeclared']);
                        final pitDeclared = asNum(t['pitDeclared']);
                        final vatPaid = asNum(t['vatPaid']);
                        final pitPaid = asNum(t['pitPaid']);
                        final remaining =
                            (vatDeclared + pitDeclared) - (vatPaid + pitPaid);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: c.divider.withValues(alpha: 0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.01),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    t['period'] ?? 'Kỳ kê khai',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_note_rounded,
                                          size: 20,
                                        ),
                                        color: theme.colorScheme.primary,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        tooltip: 'Chỉnh sửa',
                                        onPressed: () =>
                                            _showEditDialog(context, ref, t),
                                        splashRadius: 20,
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_sweep_rounded,
                                          size: 20,
                                        ),
                                        color: AppColors.danger,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        tooltip: 'Xóa kỳ thuế',
                                        onPressed: id == null
                                            ? null
                                            : () => _confirmDelete(
                                                context,
                                                ref,
                                                id,
                                              ),
                                        splashRadius: 20,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              _taxRowItem(
                                'Thuế GTGT (VAT)',
                                _fmt(vatDeclared),
                                _fmt(vatPaid),
                                vatPaid >= vatDeclared,
                                c,
                              ),
                              const SizedBox(height: 6),
                              _taxRowItem(
                                'Thuế TNCN',
                                _fmt(pitDeclared),
                                _fmt(pitPaid),
                                pitPaid >= pitDeclared,
                                c,
                              ),

                              if (remaining > 0) ...[
                                Divider(
                                  color: c.divider.withValues(alpha: 0.4),
                                  height: 20,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Còn phải nộp kỳ này:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      _fmt(remaining),
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.danger,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: compactLayout
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, ref),
              icon: const Icon(Icons.account_balance_rounded),
              label: Text(
                'Khai thuế mới',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
              ),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
    );
  }

  Widget _taxRowItem(
    String label,
    String declared,
    String paid,
    bool isPaidComplete,
    AppThemeColors c,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Khai: $declared',
          style: TextStyle(
            fontSize: 11,
            color: c.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Đã nộp: $paid',
          style: TextStyle(
            fontSize: 11,
            color: isPaidComplete ? AppColors.success : AppColors.warning,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _AddTaxObligationDialog(ref: ref),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> t,
  ) {
    if (t['id'] == null) return;
    showDialog(
      context: context,
      builder: (_) => _EditTaxObligationDialog(ref: ref, item: t),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final confirmed = await AppConfirmModal.show(
      context,
      title: 'Xóa kỳ nghĩa vụ thuế?',
      message:
          'Bạn có chắc chắn muốn xóa kỳ thuế này khỏi sổ cái? Dữ liệu không thể phục hồi.',
      confirmText: 'Xóa kỳ thuế',
      cancelText: 'Hủy',
      isDestructive: true,
    );
    if (confirmed == true) {
      try {
        await ref.read(financeRepoProvider).deleteTaxObligation(id);
        ToastService.showSuccess('Đã xóa kỳ thuế thành công');
        ref.invalidate(taxObligationsProvider);
      } catch (e) {
        ToastService.showError('Không thể xóa kỳ thuế. Vui lòng thử lại sau.');
      }
    }
  }
}

class _AddTaxObligationDialog extends StatefulWidget {
  final WidgetRef ref;
  const _AddTaxObligationDialog({required this.ref});

  @override
  State<_AddTaxObligationDialog> createState() =>
      _AddTaxObligationDialogState();
}

class _AddTaxObligationDialogState extends State<_AddTaxObligationDialog> {
  late final TextEditingController _periodC;
  late final TextEditingController _vatC;
  late final TextEditingController _pitC;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _periodC = TextEditingController(
      text: 'Q${((DateTime.now().month - 1) ~/ 3) + 1}/${DateTime.now().year}',
    );
    _vatC = TextEditingController();
    _pitC = TextEditingController();
  }

  @override
  void dispose() {
    _periodC.dispose();
    _vatC.dispose();
    _pitC.dispose();
    super.dispose();
  }

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final vatVal = parseCurrency(_vatC.text);
    final pitVal = parseCurrency(_pitC.text);

    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Thêm kỳ nghĩa vụ thuế',
        style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _periodC,
              decoration: const InputDecoration(
                labelText: 'Kỳ kê khai (VD: Q1/2026) *',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vatC,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Thuế VAT phải nộp (VNĐ)',
                hintText: '0',
                helperText: vatVal > 0 ? 'Quy đổi: ${_fmt(vatVal)}' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pitC,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Thuế TNCN phải nộp (VNĐ)',
                hintText: '0',
                helperText: pitVal > 0 ? 'Quy đổi: ${_fmt(pitVal)}' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(
            'Hủy',
            style: TextStyle(
              color: c.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _submitting
              ? null
              : () async {
                  final period = _periodC.text.trim();
                  if (period.isEmpty) {
                    ToastService.showError('Vui lòng nhập kỳ kê khai');
                    return;
                  }
                  final vat = parseCurrency(_vatC.text);
                  final pit = parseCurrency(_pitC.text);
                  if (vat < 0 || pit < 0) {
                    ToastService.showError('Số tiền thuế không được âm');
                    return;
                  }
                  setState(() => _submitting = true);
                  final navigator = Navigator.of(context);
                  try {
                    await widget.ref
                        .read(financeRepoProvider)
                        .createTaxObligation({
                          'period': period,
                          'vatDeclared': vat,
                          'pitDeclared': pit,
                        });
                    widget.ref.invalidate(taxObligationsProvider);
                    if (mounted) {
                      navigator.pop();
                      ToastService.showSuccess('Đã thêm kỳ nghĩa vụ thuế');
                    }
                  } catch (e) {
                    ToastService.showError(
                      'Không thể thêm kỳ thuế. Vui lòng thử lại sau.',
                    );
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu lại'),
        ),
      ],
    );
  }
}

class _EditTaxObligationDialog extends StatefulWidget {
  final WidgetRef ref;
  final Map<String, dynamic> item;
  const _EditTaxObligationDialog({required this.ref, required this.item});

  @override
  State<_EditTaxObligationDialog> createState() =>
      _EditTaxObligationDialogState();
}

class _EditTaxObligationDialogState extends State<_EditTaxObligationDialog> {
  late final TextEditingController _periodC;
  late final TextEditingController _vatC;
  late final TextEditingController _pitC;
  late final TextEditingController _vatPaidC;
  late final TextEditingController _pitPaidC;
  late String _selectedStatus;
  bool _submitting = false;

  static const _statuses = ['pending', 'partial', 'done', 'overdue'];
  static const _statusLabels = {
    'pending': 'Chờ nộp',
    'partial': 'Một phần',
    'done': 'Hoàn thành',
    'overdue': 'Quá hạn',
  };

  @override
  void initState() {
    super.initState();
    final t = widget.item;
    _periodC = TextEditingController(text: t['period']?.toString() ?? '');
    _vatC = TextEditingController(
      text: asNum(t['vatDeclared']).toInt().toString(),
    );
    _pitC = TextEditingController(
      text: asNum(t['pitDeclared']).toInt().toString(),
    );
    _vatPaidC = TextEditingController(
      text: asNum(t['vatPaid']).toInt().toString(),
    );
    _pitPaidC = TextEditingController(
      text: asNum(t['pitPaid']).toInt().toString(),
    );
    _selectedStatus = t['status']?.toString() ?? 'pending';
  }

  @override
  void dispose() {
    _periodC.dispose();
    _vatC.dispose();
    _pitC.dispose();
    _vatPaidC.dispose();
    _pitPaidC.dispose();
    super.dispose();
  }

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final id = widget.item['id'] as int?;
    final vatVal = parseCurrency(_vatC.text);
    final pitVal = parseCurrency(_pitC.text);
    final vatPaidVal = parseCurrency(_vatPaidC.text);
    final pitPaidVal = parseCurrency(_pitPaidC.text);

    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Cập nhật kỳ thuế',
        style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _periodC,
              decoration: const InputDecoration(
                labelText: 'Kỳ kê khai (VD: Q1/2026) *',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vatC,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'VAT khai nộp',
                helperText: vatVal > 0 ? 'Quy đổi: ${_fmt(vatVal)}' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pitC,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'TNCN khai nộp',
                helperText: pitVal > 0 ? 'Quy đổi: ${_fmt(pitVal)}' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vatPaidC,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'VAT thực tế đã nộp',
                helperText: vatPaidVal > 0
                    ? 'Quy đổi: ${_fmt(vatPaidVal)}'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pitPaidC,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'TNCN thực tế đã nộp',
                helperText: pitPaidVal > 0
                    ? 'Quy đổi: ${_fmt(pitPaidVal)}'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Trạng thái nghĩa vụ',
              ),
              items: _statuses
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(_statusLabels[s] ?? s),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedStatus = v ?? _selectedStatus),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(
            'Hủy',
            style: TextStyle(
              color: c.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _submitting || id == null
              ? null
              : () async {
                  final period = _periodC.text.trim();
                  if (period.isEmpty) {
                    ToastService.showError('Vui lòng nhập kỳ kê khai');
                    return;
                  }
                  final vat = parseCurrency(_vatC.text);
                  final pit = parseCurrency(_pitC.text);
                  final vatPaid = parseCurrency(_vatPaidC.text);
                  final pitPaid = parseCurrency(_pitPaidC.text);
                  if (vat < 0 || pit < 0 || vatPaid < 0 || pitPaid < 0) {
                    ToastService.showError('Số tiền thuế không được âm');
                    return;
                  }
                  setState(() => _submitting = true);
                  final navigator = Navigator.of(context);
                  try {
                    await widget.ref
                        .read(financeRepoProvider)
                        .updateTaxObligation(id, {
                          'period': period,
                          'vatDeclared': vat,
                          'pitDeclared': pit,
                          'vatPaid': vatPaid,
                          'pitPaid': pitPaid,
                          'status': _selectedStatus,
                        });
                    widget.ref.invalidate(taxObligationsProvider);
                    if (mounted) {
                      navigator.pop();
                      ToastService.showSuccess('Đã cập nhật kỳ thuế');
                    }
                  } catch (e) {
                    ToastService.showError(
                      'Không thể cập nhật kỳ thuế. Vui lòng thử lại sau.',
                    );
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
