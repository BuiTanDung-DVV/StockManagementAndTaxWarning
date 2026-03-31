import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../providers/system_provider.dart';

class ShopProfileScreen extends ConsumerStatefulWidget {
  const ShopProfileScreen({super.key});
  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _taxCodeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerIdCtrl = TextEditingController();
  final _bizLicenseCtrl = TextEditingController();
  final _receiptFooterCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final repo = ref.read(systemRepoProvider);
      final data = await repo.getShopProfile();
      final d = data['data'] ?? data;
      _shopNameCtrl.text = d['shopName'] ?? d['shop_name'] ?? '';
      _phoneCtrl.text = d['phone'] ?? '';
      _addressCtrl.text = d['address'] ?? '';
      _taxCodeCtrl.text = d['taxCode'] ?? d['tax_code'] ?? '';
      _emailCtrl.text = d['email'] ?? '';
      _websiteCtrl.text = d['website'] ?? '';
      _ownerNameCtrl.text = d['ownerName'] ?? d['owner_name'] ?? '';
      _ownerIdCtrl.text = d['ownerIdentityNumber'] ?? d['owner_identity_number'] ?? '';
      _bizLicenseCtrl.text = d['businessLicenseNumber'] ?? d['business_license_number'] ?? '';
      _receiptFooterCtrl.text = d['receiptFooter'] ?? d['receipt_footer'] ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(systemRepoProvider);
      await repo.saveShopProfile({
        'shopName': _shopNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'taxCode': _taxCodeCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'ownerName': _ownerNameCtrl.text.trim(),
        'ownerIdentityNumber': _ownerIdCtrl.text.trim(),
        'businessLicenseNumber': _bizLicenseCtrl.text.trim(),
        'receiptFooter': _receiptFooterCtrl.text.trim(),
      });
      ref.invalidate(shopProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật thông tin shop thành công!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _taxCodeCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerIdCtrl.dispose();
    _bizLicenseCtrl.dispose();
    _receiptFooterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin cửa hàng'),
        actions: [
          if (!_loading)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: AppColors.primary, size: 18),
              label: Text(_saving ? 'Đang lưu...' : 'Lưu', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const ShimmerList(count: 6)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ── Thông tin cửa hàng ──
                  _SectionHeader(icon: HugeIcons.strokeRoundedStore01, title: 'Thông tin cơ bản'),
                  const SizedBox(height: 12),
                  _buildField('Tên cửa hàng *', _shopNameCtrl, HugeIcons.strokeRoundedStore01, c,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên shop' : null),
                  const SizedBox(height: 12),
                  _buildField('Số điện thoại', _phoneCtrl, HugeIcons.strokeRoundedCall02, c,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildField('Địa chỉ', _addressCtrl, HugeIcons.strokeRoundedLocation01, c,
                      maxLines: 2),
                  const SizedBox(height: 12),
                  _buildField('Email', _emailCtrl, HugeIcons.strokeRoundedMail01, c,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _buildField('Website', _websiteCtrl, HugeIcons.strokeRoundedGlobe02, c,
                      keyboardType: TextInputType.url),

                  const SizedBox(height: 24),
                  // ── Thông tin pháp lý ──
                  _SectionHeader(icon: HugeIcons.strokeRoundedLicenseDraft, title: 'Thông tin pháp lý (HKD)'),
                  const SizedBox(height: 12),
                  _buildField('Mã số thuế', _taxCodeCtrl, HugeIcons.strokeRoundedInvoice01, c),
                  const SizedBox(height: 12),
                  _buildField('Tên chủ hộ kinh doanh', _ownerNameCtrl, HugeIcons.strokeRoundedUser, c),
                  const SizedBox(height: 12),
                  _buildField('CCCD / CMND chủ hộ', _ownerIdCtrl, HugeIcons.strokeRoundedId, c,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _buildField('Số GPKD', _bizLicenseCtrl, HugeIcons.strokeRoundedLicenseDraft, c),

                  const SizedBox(height: 24),
                  // ── Khác ──
                  _SectionHeader(icon: HugeIcons.strokeRoundedInvoice03, title: 'Hóa đơn'),
                  const SizedBox(height: 12),
                  _buildField('Chân hóa đơn', _receiptFooterCtrl, HugeIcons.strokeRoundedTextFootnote, c,
                      maxLines: 3, hint: 'VD: Cảm ơn quý khách! Hẹn gặp lại.'),

                  const SizedBox(height: 32),
                  // ── Save button ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: Colors.white, size: 18),
                      label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    dynamic icon,
    AppThemeColors c, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: HugeIcon(icon: icon, size: 20, color: AppColors.primary),
        ),
        filled: true,
        fillColor: c.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ── Section header ──
class _SectionHeader extends StatelessWidget {
  final dynamic icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      HugeIcon(icon: icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }
}
