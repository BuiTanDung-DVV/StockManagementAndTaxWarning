import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/supplier_provider.dart';
import 'supplier_form_screen.dart';
import 'supplier_payables_section.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class SupplierDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const SupplierDetailScreen({super.key, required this.id});

  @override
  ConsumerState<SupplierDetailScreen> createState() =>
      _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends ConsumerState<SupplierDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final c = AppThemeColors.of(context);
    final detailAsync = ref.watch(supplierDetailProvider(widget.id));
    final compactLayout = MediaQuery.sizeOf(context).width < 720;
    Future<void> openEdit() async {
      final supplier = detailAsync.value;
      if (supplier == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupplierFormScreen(supplier: supplier),
        ),
      );
      ref.invalidate(supplierDetailProvider(widget.id));
      ref.invalidate(supplierListProvider);
    }

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
          'Nhà cung cấp',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const AppIcon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Ngừng sử dụng nhà cung cấp',
            onPressed: () => _confirmDelete(context, ref),
          ),
          featureGuideButton(context, 'supplier_detail'),
          if (!compactLayout && detailAsync.hasValue)
            AppPrimaryPageAction(
              label: 'Chỉnh sửa',
              assetPath: AppAssets.edit,
              onPressed: openEdit,
            ),
          if (compactLayout && detailAsync.hasValue)
            AppPrimaryHeaderAction(
              label: 'Chỉnh sửa',
              assetPath: AppAssets.edit,
              heroTag: 'supplier-edit-compact',
              onPressed: openEdit,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppInlineError(
              message:
                  'Không tải được dữ liệu nhà cung cấp: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}',
              onRetry: () => ref.invalidate(supplierDetailProvider(widget.id)),
            ),
          ),
        ),
        data: (s) {
          final name = s['name'] ?? 'Nhà cung cấp ẩn danh';
          final contactName =
              s['contactName'] ?? s['contactPerson'] ?? s['contact'] ?? '';
          final phone = s['phone'] ?? '';
          final email = s['email'] ?? '';
          final address = s['address'] ?? '';
          final taxCode = s['taxCode'] ?? '';
          final bankName = s['bankName'] ?? '';
          final bankAccount = s['bankAccount'] ?? '';
          final paymentTerms = s['paymentTerms'] ?? s['paymentTermDays'] ?? '';
          final balance = asDouble(
            s['balance'] ?? s['totalPayables'] ?? s['debt'] ?? s['totalDebt'],
          );
          final totalPurchase = asDouble(
            s['totalPurchase'] ?? s['total_purchase'] ?? s['totalPurchases'],
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(supplierDetailProvider(widget.id));
              ref.invalidate(supplierListProvider);
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: c.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                  ),
                                ),
                                if ((s['code']?.toString() ?? '').isNotEmpty)
                                  Text(
                                    s['code'].toString(),
                                    style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SupplierLedgerSummary(
                        balance: balance,
                        totalPurchase: totalPurchase,
                      ),
                      const SizedBox(height: 16),
                      SupplierPayablesSection(
                        supplierId: widget.id,
                        supplierName: name.toString(),
                      ),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Thông tin liên hệ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Info Section 1: Business Parameters
                      _Card([
                        if (taxCode.isNotEmpty)
                          _R('Mã số thuế (MST)', taxCode, c),
                        if (contactName.isNotEmpty)
                          _R('Người đại diện liên hệ', contactName, c),
                        if (phone.isNotEmpty)
                          _R('Điện thoại liên lạc', phone, c),
                        if (email.isNotEmpty)
                          _R('Địa chỉ thư điện tử', email, c),
                        if (address.isNotEmpty)
                          _R('Địa chỉ văn phòng', address, c),
                        if (bankName.isNotEmpty)
                          _R('Ngân hàng thụ hưởng', bankName, c),
                        if (bankAccount.isNotEmpty)
                          _R('Số tài khoản ngân hàng', bankAccount, c),
                        if (paymentTerms.toString().isNotEmpty)
                          _R(
                            'Kỳ hạn thanh toán nợ',
                            _formatPaymentTerm(paymentTerms),
                            c,
                          ),
                      ]),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            icon: const AppIcon(Icons.phone_rounded, size: 16),
                            label: const Text('Gọi cho nhà cung cấp'),
                            onPressed: () async {
                              final uri = Uri.parse('tel:$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                ToastService.showError(
                                  'Không thể thực hiện cuộc gọi',
                                );
                              }
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      if (phone.isEmpty && email.isEmpty && address.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Thông tin liên hệ của nhà cung cấp chưa được cập nhật đầy đủ.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: c.textMuted,
                              fontSize: 12,
                              height: 1.4,
                            ),
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
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppConfirmModal.show(
      context,
      title: 'Ngừng sử dụng nhà cung cấp',
      message:
          'Nhà cung cấp sẽ được ẩn khỏi danh sách sử dụng. Công nợ và chứng từ đã ghi vẫn được giữ.',
      confirmText: 'Ngừng sử dụng',
      isDestructive: true,
    );
    if (confirmed != true) return;

    final cancel = BotToast.showCustomLoading(
      toastBuilder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await ref.read(supplierRepoProvider).delete(widget.id);
      cancel();
      ToastService.showSuccess('Đã ngừng sử dụng nhà cung cấp');
      ref.invalidate(supplierListProvider);
      if (context.mounted) context.pop();
    } catch (e) {
      cancel();
      ToastService.showError(
        'Chưa thể ngừng sử dụng nhà cung cấp. Vui lòng thử lại.',
      );
    }
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card(this.children);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(
          12,
        ), // Taste-Skill Shape Consistency
        border: Border.all(color: c.divider), // Solid border, no alpha
      ),
      child: Column(children: children),
    );
  }
}

class _SupplierLedgerSummary extends StatelessWidget {
  final double balance, totalPurchase;
  const _SupplierLedgerSummary({
    required this.balance,
    required this.totalPurchase,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    Widget metric(String label, double value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        Text(
          _currFmt.format(value),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
      ],
    );
    return _Card([
      LayoutBuilder(
        builder: (context, constraints) {
          if (totalPurchase <= 0) {
            return Align(
              alignment: Alignment.centerLeft,
              child: metric('Còn phải trả nhà cung cấp', balance),
            );
          }
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                metric('Còn phải trả nhà cung cấp', balance),
                const Divider(height: 24),
                _R('Lũy kế nhập hàng', _currFmt.format(totalPurchase), c),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: metric('Còn phải trả nhà cung cấp', balance)),
              Container(width: 1, height: 52, color: c.divider),
              const SizedBox(width: 24),
              Expanded(child: metric('Lũy kế nhập hàng', totalPurchase)),
            ],
          );
        },
      ),
    ]);
  }
}

class _R extends StatelessWidget {
  final String l, v;
  final AppThemeColors c;
  const _R(this.l, this.v, this.c);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: constraints.maxWidth < 500 ? 118 : 180,
            child: Text(
              l,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              v,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatPaymentTerm(dynamic term, {String fallback = '—'}) {
  if (term == null) return fallback;
  final s = term.toString().trim();
  if (s.isEmpty) return fallback;
  if (s.toLowerCase().contains('ngày')) return s;
  final numVal = num.tryParse(s);
  if (numVal != null) return '$s ngày';
  return s;
}
