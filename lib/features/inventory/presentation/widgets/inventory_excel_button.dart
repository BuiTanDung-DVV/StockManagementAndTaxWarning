import 'package:flutter/material.dart';

import '../../../../core/utils/excel_export_service.dart';
import '../../../../core/utils/report_xlsx_writer.dart';
import '../../../../core/utils/toast_service.dart';

class InventoryExcelButton extends StatefulWidget {
  const InventoryExcelButton({
    super.key,
    required this.filename,
    required this.title,
    required this.scope,
    required this.headers,
    required this.widths,
    required this.records,
    this.label = 'Xuất Excel trang này',
  });

  final String filename;
  final String title;
  final String scope;
  final List<String> headers;
  final List<double> widths;
  final List<List<XlsxCell?>> records;
  final String label;

  static XlsxCell? number(Object? value) {
    final parsed = num.tryParse(value?.toString() ?? '');
    return parsed != null && parsed.isFinite
        ? XlsxCell.number(parsed.toString())
        : null;
  }

  @override
  State<InventoryExcelButton> createState() => _InventoryExcelButtonState();
}

class _InventoryExcelButtonState extends State<InventoryExcelButton> {
  bool _saving = false;

  Future<void> _export() async {
    setState(() => _saving = true);
    try {
      final saved = await ExcelExportService.exportRecords(
        filename: widget.filename,
        title: widget.title,
        scope: widget.scope,
        headers: widget.headers,
        widths: widget.widths,
        records: widget.records,
      );
      if (!mounted) return;
      if (saved) {
        ToastService.showSuccess('Đã xuất tệp Excel');
      } else {
        ToastService.showError('Chưa lưu được tệp Excel. Vui lòng thử lại.');
      }
    } catch (_) {
      if (mounted) {
        ToastService.showError('Không thể tạo tệp Excel. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _saving || widget.records.isEmpty ? null : _export,
    icon: const Icon(Icons.download_outlined, size: 18),
    label: Text(_saving ? 'Đang xuất…' : widget.label),
  );
}
