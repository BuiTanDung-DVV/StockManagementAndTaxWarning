import '../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../constants/vietnam_provinces.dart';

class AddressInputField extends StatefulWidget {
  final String label;
  final String initialValue;
  final Function(String) onChanged;
  final AppThemeColors colors;

  const AddressInputField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    required this.colors,
  });

  @override
  State<AddressInputField> createState() => _AddressInputFieldState();
}

class _AddressInputFieldState extends State<AddressInputField> {
  late final TextEditingController _detailCtrl;
  String? _selectedProvince;

  @override
  void initState() {
    super.initState();
    _parseInitialValue();
    _detailCtrl = TextEditingController(text: _getDetailPart());
    _detailCtrl.addListener(_emitChange);
  }

  void _parseInitialValue() {
    if (widget.initialValue.isEmpty) return;
    final parts = widget.initialValue.split(',');
    if (parts.isNotEmpty) {
      final lastPart = parts.last.trim();
      if (vietnamProvinces.contains(lastPart) ||
          legacyVietnamProvinces.contains(lastPart)) {
        _selectedProvince = lastPart;
      }
    }
  }

  String _getDetailPart() {
    if (widget.initialValue.isEmpty) return '';
    if (_selectedProvince == null) return widget.initialValue;
    if (widget.initialValue.trim() == _selectedProvince) return '';
    final separator = widget.initialValue.lastIndexOf(',');
    if (separator >= 0 &&
        widget.initialValue.substring(separator + 1).trim() ==
            _selectedProvince) {
      return widget.initialValue.substring(0, separator).trim();
    }
    return widget.initialValue;
  }

  void _emitChange() {
    final detail = _detailCtrl.text.trim();
    if (_selectedProvince != null && _selectedProvince!.isNotEmpty) {
      if (detail.isEmpty) {
        widget.onChanged(_selectedProvince!);
      } else {
        widget.onChanged('$detail, $_selectedProvince');
      }
    } else {
      widget.onChanged(detail);
    }
  }

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedProvince,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Tỉnh/Thành phố',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: AppHugeIcon(
                icon: HugeIcons.strokeRoundedLocation01,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            filled: true,
            fillColor: c.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: [
            if (_selectedProvince != null &&
                !vietnamProvinces.contains(_selectedProvince))
              DropdownMenuItem(
                value: _selectedProvince,
                child: Text('$_selectedProvince (địa chỉ cũ)'),
              ),
            ...vietnamProvinces.map(
              (p) => DropdownMenuItem(value: p, child: Text(p)),
            ),
          ],
          onChanged: (v) {
            setState(() => _selectedProvince = v);
            _emitChange();
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _detailCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Chi tiết địa chỉ (Số nhà, đường, phường/xã)',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: AppHugeIcon(
                icon: HugeIcons.strokeRoundedLocation01,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            filled: true,
            fillColor: c.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
