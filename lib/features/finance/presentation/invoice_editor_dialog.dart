import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/business_date_field.dart';

class InvoiceEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? initialInvoice;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  const InvoiceEditorDialog({
    super.key,
    this.initialInvoice,
    required this.onSubmit,
  });

  @override
  State<InvoiceEditorDialog> createState() => _InvoiceEditorDialogState();
}

class _InvoiceEditorDialogState extends State<InvoiceEditorDialog> {
  late final TextEditingController _numberController;
  late final TextEditingController _partnerController;
  late String _type;
  late DateTime _invoiceDate;
  late List<_InvoiceLineControllers> _lines;
  final List<_InvoiceLineControllers> _retiredLines = [];
  bool _saving = false;
  String? _error;

  late String _initialSnapshot;
  bool _forceClose = false;
  bool _showingDiscardDialog = false;

  final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  String _getFormSnapshot() {
    final items = _lines
        .map(
          (l) => {
            'name': l.name.text,
            'unit': l.unit.text,
            'quantity': l.quantity.text,
            'price': l.unitPrice.text,
            'tax': l.taxRate.text,
          },
        )
        .toList();
    return jsonEncode({
      'type': _type,
      'number': _numberController.text,
      'partner': _partnerController.text,
      'date': _invoiceDate.toIso8601String().split('T').first,
      'items': items,
    });
  }

  bool get _isDirty => _getFormSnapshot() != _initialSnapshot;

  @override
  void initState() {
    super.initState();
    final invoice = widget.initialInvoice;
    _numberController = TextEditingController(
      text: invoice?['invoiceNumber']?.toString() ?? '',
    );
    _partnerController = TextEditingController(
      text: invoice?['partnerName']?.toString() ?? '',
    );
    _type = invoice?['invoiceType']?.toString() == 'OUT' ? 'OUT' : 'IN';

    final initialDateStr = invoice?['invoiceDate']?.toString();
    if (initialDateStr != null && initialDateStr.isNotEmpty) {
      try {
        _invoiceDate = DateTime.parse(initialDateStr.split('T').first);
      } catch (_) {
        _invoiceDate = DateTime.now();
      }
    } else {
      _invoiceDate = DateTime.now();
    }

    final initialItems = ((invoice?['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => _InvoiceLineControllers.fromMap(item))
        .toList();
    _lines = initialItems.isEmpty
        ? [_InvoiceLineControllers.empty()]
        : initialItems;
    _initialSnapshot = _getFormSnapshot();
  }

  @override
  void dispose() {
    _numberController.dispose();
    _partnerController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    for (final line in _retiredLines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _lines.fold(0, (sum, line) => sum + line.subtotal);
  double get _taxAmount => _lines.fold(0, (sum, line) => sum + line.taxAmount);

  void _addLine() {
    setState(() {
      _lines.add(_InvoiceLineControllers.empty());
      _error = null;
    });
  }

  void _removeLine(int index) {
    if (_lines.length == 1) {
      setState(() => _error = 'Hóa đơn phải có ít nhất một dòng hàng.');
      return;
    }
    final removed = _lines.removeAt(index);
    _retiredLines.add(removed);
    setState(() => _error = null);
  }

  Future<void> _handleClose() async {
    if (_saving) return;
    if (!_isDirty) {
      _forceClose = true;
      if (mounted) Navigator.pop(context);
      return;
    }
    if (_showingDiscardDialog) return;
    _showingDiscardDialog = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ thay đổi hóa đơn?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục chỉnh sửa'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    _showingDiscardDialog = false;
    if (discard == true && mounted) {
      _forceClose = true;
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final partner = _partnerController.text.trim();
    if (partner.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên đối tác.');
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(
      _invoiceDate.year,
      _invoiceDate.month,
      _invoiceDate.day,
    );
    if (selectedDateOnly.isAfter(today)) {
      setState(() => _error = 'Ngày hóa đơn không được ở tương lai.');
      return;
    }

    for (var index = 0; index < _lines.length; index++) {
      final error = _lines[index].validate(index + 1);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit({
        'invoiceType': _type,
        'invoiceNumber': _numberController.text.trim().isEmpty
            ? null
            : _numberController.text.trim(),
        'partnerName': partner,
        'invoiceDate': _invoiceDate.toIso8601String().split('T').first,
        'items': _lines.map((line) => line.toPayload()).toList(),
      });
      if (mounted) {
        _forceClose = true;
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Không thể lưu hóa đơn. Vui lòng kiểm tra dữ liệu và thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final total = _subtotal + _taxAmount;

    return PopScope(
      canPop: _forceClose || (!_isDirty && !_saving),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleClose();
      },
      child: AlertDialog(
        title: Text(
          widget.initialInvoice == null ? 'Thêm hóa đơn' : 'Chỉnh sửa hóa đơn',
        ),
        content: SizedBox(
          width: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact =
                              constraints.maxWidth <
                              600 * MediaQuery.textScalerOf(context).scale(1);
                          final fields = [
                            DropdownButtonFormField<String>(
                              initialValue: _type,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Loại hóa đơn',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'IN',
                                  child: Text('Đầu vào'),
                                ),
                                DropdownMenuItem(
                                  value: 'OUT',
                                  child: Text('Đầu ra'),
                                ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (value) =>
                                        setState(() => _type = value ?? 'IN'),
                            ),
                            TextField(
                              controller: _numberController,
                              enabled: !_saving,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Số hóa đơn',
                                helperText: 'Không bắt buộc',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                            ),
                            BusinessDateField(
                              label: 'Ngày hóa đơn',
                              selectedDate: _invoiceDate,
                              enabled: !_saving,
                              onChanged: (date) {
                                setState(() {
                                  _invoiceDate = date;
                                });
                              },
                            ),
                            TextField(
                              controller: _partnerController,
                              enabled: !_saving,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Đối tác',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                            ),
                          ];
                          if (compact) {
                            return Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < fields.length;
                                  index++
                                ) ...[
                                  fields[index],
                                  if (index < fields.length - 1)
                                    const SizedBox(height: AppSpacing.sm),
                                ],
                              ],
                            );
                          }
                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 2, child: fields[0]),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(flex: 3, child: fields[1]),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(flex: 3, child: fields[2]),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              fields[3],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Dòng hàng hóa, dịch vụ',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton(
                            onPressed: _saving ? null : _addLine,
                            child: const Text('Thêm dòng'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (var index = 0; index < _lines.length; index++) ...[
                        _InvoiceLineEditor(
                          index: index,
                          line: _lines[index],
                          enabled: !_saving,
                          onChanged: () => setState(() => _error = null),
                          onRemove: () => _removeLine(index),
                          money: _money,
                        ),
                        if (index < _lines.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.cardAlt,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: colors.divider),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text('Trước thuế: ${_money.format(_subtotal)}'),
                    Text('VAT: ${_money.format(_taxAmount)}'),
                    Text(
                      'Tổng cộng: ${_money.format(total)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _saving ? null : _handleClose,
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Đang lưu…' : 'Lưu hóa đơn'),
          ),
        ],
      ),
    );
  }
}

class _InvoiceLineEditor extends StatelessWidget {
  final int index;
  final _InvoiceLineControllers line;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final NumberFormat money;

  const _InvoiceLineEditor({
    required this.index,
    required this.line,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dòng ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: enabled ? onRemove : null,
                child: const Text('Xóa dòng'),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth <
                  600 * MediaQuery.textScalerOf(context).scale(1);
              final name = TextField(
                controller: line.name,
                enabled: enabled,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  labelText: 'Tên hàng hóa/dịch vụ',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              );
              final unit = TextField(
                controller: line.unit,
                enabled: enabled,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  labelText: 'Đơn vị tính',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              );
              final quantity = TextField(
                controller: line.quantity,
                enabled: enabled,
                onChanged: (_) => onChanged(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số lượng',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              );
              final price = TextField(
                controller: line.unitPrice,
                enabled: enabled,
                onChanged: (_) => onChanged(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Đơn giá (đ)',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              );
              final tax = TextField(
                controller: line.taxRate,
                enabled: enabled,
                onChanged: (_) => onChanged(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'VAT (%)',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              );
              if (compact) {
                return Column(
                  children: [
                    name,
                    const SizedBox(height: AppSpacing.xs),
                    unit,
                    const SizedBox(height: AppSpacing.xs),
                    quantity,
                    const SizedBox(height: AppSpacing.xs),
                    price,
                    const SizedBox(height: AppSpacing.xs),
                    tax,
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 3, child: name),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(flex: 1, child: unit),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(flex: 1, child: quantity),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(flex: 2, child: price),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(flex: 1, child: tax),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Thành tiền: ${money.format(line.subtotal + line.taxAmount)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceLineControllers {
  final TextEditingController name;
  final TextEditingController unit;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController taxRate;

  _InvoiceLineControllers({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
  });

  factory _InvoiceLineControllers.empty() => _InvoiceLineControllers(
    name: TextEditingController(),
    unit: TextEditingController(text: 'Cái'),
    quantity: TextEditingController(text: '1'),
    unitPrice: TextEditingController(text: '0'),
    taxRate: TextEditingController(text: '0'),
  );

  factory _InvoiceLineControllers.fromMap(Map<dynamic, dynamic> item) =>
      _InvoiceLineControllers(
        name: TextEditingController(text: item['itemName']?.toString() ?? ''),
        unit: TextEditingController(text: item['unit']?.toString() ?? 'Cái'),
        quantity: TextEditingController(
          text: asNum(item['quantity']).toInt().toString(),
        ),
        unitPrice: TextEditingController(
          text: asNum(item['unitPrice']).toStringAsFixed(0),
        ),
        taxRate: TextEditingController(
          text: asNum(item['taxRate']).toStringAsFixed(0),
        ),
      );

  int? get parsedQuantity {
    final raw = quantity.text.trim();
    if (raw.isEmpty) return null;
    final parsed = parseQuantity(raw, fallback: -1);
    if (parsed <= 0) return null;
    return parsed.toInt();
  }

  double? get parsedUnitPrice => parseCurrency(unitPrice.text.trim());
  double? get parsedTaxRate => double.tryParse(
    taxRate.text.trim().replaceAll('%', '').replaceAll(',', '.'),
  );
  double get subtotal =>
      (parsedQuantity ?? 0) *
      (parsedUnitPrice ?? 0).clamp(0, double.infinity).toDouble();
  double get taxAmount =>
      subtotal * (parsedTaxRate ?? 0).clamp(0, 100).toDouble() / 100;

  String? validate(int lineNumber) {
    if (name.text.trim().isEmpty) return 'Dòng $lineNumber chưa có tên hàng.';
    if (unit.text.trim().isEmpty) return 'Dòng $lineNumber chưa có đơn vị.';
    if (parsedQuantity == null || parsedQuantity! <= 0) {
      return 'Số lượng dòng $lineNumber phải là số nguyên lớn hơn 0.';
    }
    if (parsedUnitPrice == null || parsedUnitPrice! < 0) {
      return 'Đơn giá dòng $lineNumber không hợp lệ.';
    }
    if (parsedTaxRate == null || parsedTaxRate! < 0 || parsedTaxRate! > 100) {
      return 'VAT dòng $lineNumber phải từ 0 đến 100%.';
    }
    return null;
  }

  Map<String, dynamic> toPayload() => {
    'itemName': name.text.trim(),
    'unit': unit.text.trim(),
    'quantity': parsedQuantity,
    'unitPrice': parsedUnitPrice,
    'taxRate': parsedTaxRate,
  };

  void dispose() {
    name.dispose();
    unit.dispose();
    quantity.dispose();
    unitPrice.dispose();
    taxRate.dispose();
  }
}
