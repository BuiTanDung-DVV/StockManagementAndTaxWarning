import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/supplier_provider.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? supplier; // null = create, non-null = edit
  const SupplierFormScreen({super.key, this.supplier});
  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _taxCodeCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _saving = false;
  bool get _isEdit => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.supplier!;
      _nameCtrl.text = s['name'] ?? '';
      _phoneCtrl.text = s['phone'] ?? '';
      _emailCtrl.text = s['email'] ?? '';
      _addressCtrl.text = s['address'] ?? '';
      _taxCodeCtrl.text = s['taxCode'] ?? s['tax_code'] ?? '';
      _contactPersonCtrl.text = s['contactPerson'] ?? s['contact_person'] ?? '';
      _noteCtrl.text = s['notes'] ?? s['note'] ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(supplierRepoProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'taxCode': _taxCodeCtrl.text.trim().isEmpty ? null : _taxCodeCtrl.text.trim(),
        'contactPerson': _contactPersonCtrl.text.trim().isEmpty ? null : _contactPersonCtrl.text.trim(),
        'notes': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      };
      if (_isEdit) {
        await repo.update(widget.supplier!['id'], data);
      } else {
        await repo.create(data);
      }
      ref.invalidate(supplierListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Cập nhật nhà cung cấp thành công!' : 'Thêm nhà cung cấp thành công!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _taxCodeCtrl.dispose();
    _contactPersonCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEdit ? 'Cập Nhật Đối Tác' : 'Thêm Nhà Cung Cấp',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(
                'Tên nhà cung cấp *',
                _nameCtrl,
                HugeIcons.strokeRoundedTruck,
                c,
                theme,
                validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên nhà cung cấp' : null,
              ),
              const SizedBox(height: 12),
              _field(
                'Người đại diện liên hệ',
                _contactPersonCtrl,
                HugeIcons.strokeRoundedUser,
                c,
                theme,
              ),
              const SizedBox(height: 12),
              _field(
                'Số điện thoại liên lạc',
                _phoneCtrl,
                HugeIcons.strokeRoundedCall02,
                c,
                theme,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _field(
                'Địa chỉ thư điện tử (Email)',
                _emailCtrl,
                HugeIcons.strokeRoundedMail01,
                c,
                theme,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _field(
                'Địa chỉ văn phòng giao dịch',
                _addressCtrl,
                HugeIcons.strokeRoundedLocation01,
                c,
                theme,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _field(
                'Mã số thuế doanh nghiệp (MST)',
                _taxCodeCtrl,
                HugeIcons.strokeRoundedInvoice01,
                c,
                theme,
              ),
              const SizedBox(height: 12),
              _field(
                'Ghi chú bổ sung',
                _noteCtrl,
                HugeIcons.strokeRoundedNote,
                c,
                theme,
                maxLines: 3,
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          color: Colors.white,
                          size: 18,
                        ),
                  label: Text(
                    _saving 
                        ? 'Đang lưu lại...' 
                        : (_isEdit ? 'Cập Nhật Đối Tác' : 'Thêm Nhà Cung Cấp'),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    dynamic icon,
    AppThemeColors c,
    ThemeData theme, {
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
      style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textSecondary, fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: c.textMuted, fontSize: 12),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: HugeIcon(icon: icon, size: 18, color: theme.colorScheme.primary),
        ),
        filled: true,
        fillColor: c.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
