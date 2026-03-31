import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      _noteCtrl.text = s['note'] ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(supplierRepoProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'taxCode': _taxCodeCtrl.text.trim(),
        'contactPerson': _contactPersonCtrl.text.trim(),
        'note': _noteCtrl.text.trim(),
      };
      if (_isEdit) {
        await repo.update(widget.supplier!['id'], data);
      } else {
        await repo.create(data);
      }
      ref.invalidate(supplierListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Cập nhật thành công!' : 'Thêm NCC thành công!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, true);
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
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    _addressCtrl.dispose(); _taxCodeCtrl.dispose(); _contactPersonCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa NCC' : 'Thêm nhà cung cấp'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: AppColors.primary, size: 18),
            label: Text(_saving ? 'Đang lưu...' : 'Lưu', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _field('Tên NCC *', _nameCtrl, HugeIcons.strokeRoundedTruck, c,
                validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên' : null),
            const SizedBox(height: 12),
            _field('Người liên hệ', _contactPersonCtrl, HugeIcons.strokeRoundedUser, c),
            const SizedBox(height: 12),
            _field('Số điện thoại', _phoneCtrl, HugeIcons.strokeRoundedCall02, c, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _field('Email', _emailCtrl, HugeIcons.strokeRoundedMail01, c, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field('Địa chỉ', _addressCtrl, HugeIcons.strokeRoundedLocation01, c, maxLines: 2),
            const SizedBox(height: 12),
            _field('Mã số thuế', _taxCodeCtrl, HugeIcons.strokeRoundedInvoice01, c),
            const SizedBox(height: 12),
            _field('Ghi chú', _noteCtrl, HugeIcons.strokeRoundedNote, c, maxLines: 3),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: Colors.white, size: 18),
                label: Text(_saving ? 'Đang lưu...' : (_isEdit ? 'Cập nhật' : 'Thêm NCC')),
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

  Widget _field(String label, TextEditingController ctrl, dynamic icon, AppThemeColors c, {
    TextInputType? keyboardType, int maxLines = 1, String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl, keyboardType: keyboardType, maxLines: maxLines, validator: validator,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Padding(padding: const EdgeInsets.all(12), child: HugeIcon(icon: icon, size: 20, color: AppColors.primary)),
        filled: true, fillColor: c.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
