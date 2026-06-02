import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/supplier_provider.dart';
import 'supplier_form_screen.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class SupplierDetailScreen extends ConsumerWidget {
  final int id;
  const SupplierDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final detailAsync = ref.watch(supplierDetailProvider(id));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Chi Tiết Nhà Cung Cấp',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'supplier_detail'),
          const SizedBox(width: 8),
        ],
      ),
      body: detailAsync.when(
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
                  'Không tải được dữ liệu nhà cung cấp\n$e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(supplierDetailProvider(id)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (s) {
          final name = s['name'] ?? 'Nhà cung cấp ẩn danh';
          final contactName = s['contactName'] ?? s['contactPerson'] ?? s['contact'] ?? '';
          final phone = s['phone'] ?? '';
          final email = s['email'] ?? '';
          final address = s['address'] ?? '';
          final taxCode = s['taxCode'] ?? '';
          final bankName = s['bankName'] ?? '';
          final bankAccount = s['bankAccount'] ?? '';
          final paymentTerms = s['paymentTerms'] ?? s['paymentTermDays'] ?? '';
          final balance = num.tryParse(s['balance']?.toString() ?? '')?.toDouble() ?? 0;
          final totalPurchase = num.tryParse(s['totalPurchase']?.toString() ?? '')?.toDouble() ?? 0;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                // Premium visual card for company logo avatar
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.15), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Info Section 1: Business Parameters
                _Card([
                  if (taxCode.isNotEmpty) _R('Mã số thuế (MST)', taxCode, c),
                  if (contactName.isNotEmpty) _R('Người đại diện liên hệ', contactName, c),
                  if (phone.isNotEmpty) _R('Điện thoại liên lạc', phone, c),
                  if (email.isNotEmpty) _R('Địa chỉ thư điện tử', email, c),
                  if (address.isNotEmpty) _R('Địa chỉ văn phòng', address, c),
                  if (bankName.isNotEmpty) _R('Ngân hàng thụ hưởng', bankName, c),
                  if (bankAccount.isNotEmpty) _R('Số tài khoản ngân hàng', bankAccount, c),
                  if (paymentTerms.toString().isNotEmpty) _R('Kỳ hạn thanh toán nợ', '$paymentTerms ngày', c),
                ]),
                const SizedBox(height: 12),

                // Info Section 2: Ledger Summary parameters
                _Card([
                  if (totalPurchase > 0) _R('Lũy kế nhập hàng từ NCC', _currFmt.format(totalPurchase), c),
                  _R(
                    'Công nợ hiện tại với NCC',
                    _currFmt.format(balance),
                    c,
                    valColor: balance > 0 ? AppColors.danger : AppColors.success,
                  ),
                ]),

                if (contactName.isEmpty && phone.isEmpty && email.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Thông tin liên hệ của nhà cung cấp chưa được cập nhật đầy đủ.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: c.textMuted, fontSize: 12, height: 1.4),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: detailAsync.hasValue ? FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SupplierFormScreen(supplier: detailAsync.value!)),
          );
          ref.invalidate(supplierDetailProvider(id));
          ref.invalidate(supplierListProvider);
        },
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ) : null,
    );
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
        borderRadius: BorderRadius.circular(12), // Taste-Skill Shape Consistency
        border: Border.all(color: c.divider), // Solid border, no alpha
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _R extends StatelessWidget {
  final String l, v;
  final AppThemeColors c;
  final Color? valColor;
  const _R(this.l, this.v, this.c, {this.valColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l,
            style: GoogleFonts.inter(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              v,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: valColor ?? c.textPrimary,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
