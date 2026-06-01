import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sectioned_form_dialog.dart';
import '../../../core/widgets/address_input_field.dart';
import '../../../core/widgets/inline_tag_picker.dart';
import '../providers/customer_provider.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? customer; // null = create, non-null = edit
  const CustomerFormScreen({super.key, this.customer});
  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _taxCodeCtrl = TextEditingController();
  List<String> _tags = [];

  bool _saving = false;
  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final c = widget.customer!;
      _nameCtrl.text = c['name'] ?? '';
      _phoneCtrl.text = c['phone'] ?? '';
      _emailCtrl.text = c['email'] ?? '';
      _addressCtrl.text = c['address'] ?? '';
      _noteCtrl.text = c['notes'] ?? c['note'] ?? '';
      _taxCodeCtrl.text = c['taxCode'] ?? c['tax_code'] ?? '';
      if (c['tags'] != null && c['tags'] is List) {
        _tags = List<String>.from(c['tags']);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepoProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'notes': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        'taxCode': _taxCodeCtrl.text.trim().isEmpty ? null : _taxCodeCtrl.text.trim(),
        'tags': _tags,
      };
      if (_isEdit) {
        await repo.update(widget.customer!['id'], data);
      } else {
        await repo.create(data);
      }
      ref.invalidate(customerListProvider);
      if (mounted) {
        ToastService.showSuccess(_isEdit ? 'Cập nhật thành công!' : 'Thêm khách hàng thành công!');
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
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    _addressCtrl.dispose(); _noteCtrl.dispose(); _taxCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Scaffold(
      backgroundColor: Colors.black26,
      body: Center(
        child: SectionedFormDialog(
          title: _isEdit ? 'Sửa khách hàng' : 'Thêm khách hàng',
          isSaving: _saving,
          saveText: _isEdit ? 'Cập nhật' : 'Thêm khách hàng',
          onSave: _save,
          onCancel: () => Navigator.of(context).pop(),
          content: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field('Tên khách hàng *', _nameCtrl, HugeIcons.strokeRoundedUser, c,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên' : null),
                const SizedBox(height: 16),
                _field('Số điện thoại', _phoneCtrl, HugeIcons.strokeRoundedCall02, c, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                _field('Email', _emailCtrl, HugeIcons.strokeRoundedMail01, c, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                AddressInputField(
                  label: 'Địa chỉ',
                  initialValue: _addressCtrl.text,
                  colors: c,
                  onChanged: (v) => _addressCtrl.text = v,
                ),
                const SizedBox(height: 16),
                _field('Mã số thuế', _taxCodeCtrl, HugeIcons.strokeRoundedInvoice01, c),
                const SizedBox(height: 16),
                _field('Ghi chú', _noteCtrl, HugeIcons.strokeRoundedNote, c, maxLines: 3),
                const SizedBox(height: 16),
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
                  type: 'customer',
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

  Widget _field(String label, TextEditingController ctrl, dynamic icon, AppThemeColors c, {
    TextInputType? keyboardType, int maxLines = 1, String? hint,
    String? Function(String?)? validator,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return TextFormField(
      controller: ctrl, keyboardType: keyboardType, maxLines: maxLines, validator: validator,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Padding(padding: const EdgeInsets.all(12), child: HugeIcon(icon: icon, size: 20, color: primaryColor)),
        filled: true, fillColor: c.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
