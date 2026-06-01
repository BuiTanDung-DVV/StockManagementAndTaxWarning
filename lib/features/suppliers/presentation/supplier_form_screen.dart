import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sectioned_form_dialog.dart';
import '../../../core/widgets/address_input_field.dart';
import '../../../core/widgets/inline_tag_picker.dart';
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
  List<String> _tags = [];

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
      if (s['tags'] != null && s['tags'] is List) {
        _tags = List<String>.from(s['tags']);
      }
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
        'tags': _tags,
      };
      if (_isEdit) {
        await repo.update(widget.supplier!['id'], data);
      } else {
        await repo.create(data);
      }
      ref.invalidate(supplierListProvider);
      if (mounted) {
        ToastService.showSuccess(_isEdit ? 'Cập nhật nhà cung cấp thành công!' : 'Thêm nhà cung cấp thành công!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError('Lỗi: $e');
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
      backgroundColor: Colors.black26,
      body: Center(
        child: SectionedFormDialog(
          title: _isEdit ? 'Cập Nhật Đối Tác' : 'Thêm Nhà Cung Cấp',
          isSaving: _saving,
          saveText: _isEdit ? 'Cập Nhật Đối Tác' : 'Thêm Nhà Cung Cấp',
          onSave: _save,
          onCancel: () => Navigator.of(context).pop(),
          content: Form(
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
                AddressInputField(
                  label: 'Địa chỉ văn phòng giao dịch',
                  initialValue: _addressCtrl.text,
                  colors: c,
                  onChanged: (v) => _addressCtrl.text = v,
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
                const SizedBox(height: 12),
                Text('Nhãn phân loại', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                const SizedBox(height: 8),
                _buildTagEditor(c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagEditor(AppThemeColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Chip(
                label: Text(tag, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                onDeleted: () => setState(() => _tags.remove(tag)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: BorderSide.none,
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: c.bg,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (ctx) {
                return InlineTagPicker(
                  type: 'supplier',
                  selectedTags: _tags,
                  onTagsChanged: (newTags) => setState(() => _tags = newTags),
                );
              },
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text('Chọn/Thêm nhãn', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
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

