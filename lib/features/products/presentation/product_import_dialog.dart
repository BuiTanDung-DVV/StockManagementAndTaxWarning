import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/excel_export_service.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../models/product_import.dart';
import '../providers/product_import_provider.dart';
import '../providers/product_provider.dart';

class ProductImportDialog extends ConsumerStatefulWidget {
  final Future<ProductImportFile?> Function()? pickFile;
  final Future<bool> Function()? downloadTemplate;
  const ProductImportDialog({super.key, this.pickFile, this.downloadTemplate});
  @override
  ConsumerState<ProductImportDialog> createState() =>
      _ProductImportDialogState();
}

class _ProductImportDialogState extends ConsumerState<ProductImportDialog> {
  late final int? _actor, _shop;
  late final String _shopName;
  ProductImportFile? _file;
  ProductImportInspection? _inspection;
  ProductImportHeader? _header;
  List<String?> _columns = [];
  String _numberFormat = 'decimal-dot';
  ProductImportPreview? _preview;
  ProductImportResult? _result;
  Map<String, dynamic>? _request;
  String? _error;
  bool _busy = false, _needsCheck = false, _errorsOnly = false;
  bool _picking = false;
  bool _closing = false;
  bool _scopeLost = false;
  bool _downloadingTemplate = false;
  String? _templateMessage;
  bool _templateFailed = false;

  @override
  void initState() {
    super.initState();
    _actor = int.tryParse('${ref.read(authProvider).user?['id']}');
    final shop = ref.read(shopProvider);
    _shop = shop.currentShopId;
    _shopName = shop.currentShopName ?? 'Cửa hàng hiện tại';
  }

  bool _current() {
    if (_scopeLost || _closing || !mounted || _actor == null || _shop == null) {
      return false;
    }
    final auth = ref.read(authProvider), shop = ref.read(shopProvider);
    return auth.isLoggedIn &&
        !auth.isOfflineSession &&
        '${auth.user?['id']}' == '$_actor' &&
        shop.currentShopId == _shop &&
        !shop.isAllShops &&
        shop.hasPermission('products', 'edit');
  }

  void _changed(VoidCallback action) => setState(() {
    action();
    _preview = null;
    _request = null;
    _error = null;
    _errorsOnly = false;
  });

  String _message(Object error) => error is ApiException
      ? error.message
      : error is FormatException
      ? error.message
      : 'Không xử lý được tệp. Hãy kiểm tra kết nối và thử lại.';

  Future<void> _downloadTemplate() async {
    if (_downloadingTemplate || _busy || _needsCheck || !_current()) return;
    setState(() {
      _downloadingTemplate = true;
      _templateMessage = null;
    });
    var downloaded = false;
    try {
      downloaded =
          await (widget.downloadTemplate ??
              ExcelExportService.downloadProductImportTemplate)();
    } catch (_) {
      downloaded = false;
    }
    if (!mounted || _closing) return;
    setState(() {
      _downloadingTemplate = false;
      if (_current()) {
        _templateFailed = !downloaded;
        _templateMessage = downloaded
            ? 'Đã gửi yêu cầu tải file mẫu. Thay hai dòng minh họa trước khi nhập.'
            : 'Chưa tải được file mẫu. Hãy thử tải lại.';
      }
    });
  }

  Future<void> _chooseFile() async {
    if (_busy || _picking || _needsCheck || !_current()) return;
    setState(() {
      _picking = true;
      _error = null;
      _preview = null;
      _request = null;
    });
    try {
      ProductImportFile? file;
      if (widget.pickFile != null) {
        file = await widget.pickFile!();
      } else {
        final picked = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'csv'],
        );
        if (picked != null) {
          final limit = picked.name.toLowerCase().endsWith('.xlsx')
              ? 5 * 1024 * 1024
              : 1024 * 1024;
          if (await picked.length() > limit) {
            throw const FormatException(
              'File quá lớn. Excel tối đa 5 MB, CSV tối đa 1 MB.',
            );
          }
          file = ProductImportFile.fromBytes(
            picked.name,
            await picked.readAsBytes(),
          );
        }
      }
      if (!_current() || file == null) return;
      setState(() {
        _picking = false;
        _busy = true;
        _file = null;
        _inspection = null;
        _header = null;
        _preview = null;
        _request = null;
      });
      final inspected = await ref
          .read(productImportRepoProvider)
          .inspect(_shop!, file.csv, _current);
      if (!_current()) return;
      setState(() {
        _file = file;
        _inspection = inspected;
        _header = inspected.candidates.firstWhere(
          (row) => row.line == inspected.defaultHeaderLine,
        );
        _columns = [..._header!.columns];
        _preview = null;
        _request = null;
        _result = null;
        if (file!.isExcel) _numberFormat = 'decimal-dot';
      });
    } catch (error) {
      if (mounted && !_closing) setState(() => _error = _message(error));
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _selectSheet(String? name) async {
    if (name == null || _file == null || _busy || !_current() || _needsCheck) {
      return;
    }
    setState(() {
      _busy = true;
      _preview = null;
      _request = null;
      _error = null;
    });
    try {
      final file = _file!.selectSheet(name);
      final inspected = await ref
          .read(productImportRepoProvider)
          .inspect(_shop!, file.csv, _current);
      if (!_current()) return;
      setState(() {
        _file = file;
        _inspection = inspected;
        _header = inspected.candidates.firstWhere(
          (row) => row.line == inspected.defaultHeaderLine,
        );
        _columns = [..._header!.columns];
        _numberFormat = 'decimal-dot';
      });
    } catch (error) {
      if (mounted && !_closing) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadPreview() async {
    if (_busy ||
        _picking ||
        _needsCheck ||
        !_current() ||
        _file == null ||
        _header == null) {
      return;
    }
    final mapped = _columns.whereType<String>().toList();
    if (!mapped.contains('sku') || mapped.toSet().length != mapped.length) {
      setState(
        () => _error = 'Gán một cột SKU; mỗi trường chỉ được gán một lần.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _preview = null;
      _request = null;
      _error = null;
    });
    try {
      final options = <String, dynamic>{
        'headerLine': _header!.line,
        'columns': [..._columns],
        'numberFormat': _numberFormat,
      };
      final preview = await ref
          .read(productImportRepoProvider)
          .preview(_shop!, _file!.csv, options, _current);
      if (!_current()) return;
      final operationId = List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      setState(() {
        _preview = preview;
        _errorsOnly = false;
        _request = {
          'operationId': operationId,
          'expectedPlanHash': preview.planHash,
          'csv': _file!.csv,
          'options': options,
        };
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _completed(ProductImportResult result) {
    if (_preview == null ||
        result.total != _preview!.total ||
        result.created != _preview!.creates ||
        result.updated != _preview!.updates ||
        result.unchanged != _preview!.unchanged) {
      throw const FormatException(
        'Kết quả chưa khớp bản xem trước; cần kiểm tra đúng mã lượt nhập.',
      );
    }
    setState(() {
      _result = result;
      _needsCheck = false;
      _error = null;
    });
    ref.invalidate(productListProvider);
    ref.invalidate(productOptionsProvider);
    ref.invalidate(productDetailProvider);
  }

  Future<void> _commit() async {
    if (_busy ||
        _picking ||
        !_current() ||
        _request == null ||
        _preview?.canCommit != true ||
        _result != null) {
      return;
    }
    setState(() {
      _busy = true;
      _needsCheck = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(productImportRepoProvider)
          .commit(_shop!, _request!, _current);
      if (!_current()) return;
      _completed(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          final rejected =
              _current() &&
              error is ApiException &&
              [400, 403, 409].contains(error.statusCode);
          _needsCheck = !rejected;
          _error = rejected
              ? _message(error)
              : 'Chưa xác định được kết quả. Kiểm tra lượt nhập hoặc thử lại cùng lượt; không chọn tệp mới.';
          if (rejected) {
            _preview = null;
            _request = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkResult() async {
    if (_busy || !_current() || _request == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(productImportRepoProvider)
          .findResult(_shop!, _request!['operationId'] as String, _current);
      if (!_current()) return;
      if (result != null) {
        _completed(result);
      } else {
        setState(
          () => _error =
              'Chưa tìm thấy kết quả đã hoàn tất. Bạn có thể thử lại cùng lượt nhập; hệ thống sẽ chống ghi trùng.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_needsCheck) {
      final close = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lượt nhập chưa rõ kết quả'),
          content: SelectableText(
            'Hãy lưu mã ${_request?['operationId']} để tra trong Nhật ký hoạt động của $_shopName. Đóng màn này không hủy được yêu cầu đã gửi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ở lại kiểm tra'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đóng màn hình'),
            ),
          ],
        ),
      );
      if (close != true || !mounted) return;
    }
    if (mounted) {
      _closing = true;
      Navigator.pop(context, _result != null || _needsCheck);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, next) {
      if (!_scopeLost &&
          (!next.isLoggedIn ||
              next.isOfflineSession ||
              '${next.user?['id']}' != '$_actor')) {
        setState(() => _scopeLost = true);
      }
    });
    ref.listen(shopProvider, (_, next) {
      if (!_scopeLost &&
          (next.currentShopId != _shop ||
              next.isAllShops ||
              !next.hasPermission('products', 'edit'))) {
        setState(() => _scopeLost = true);
      }
    });
    ref.watch(authProvider);
    ref.watch(shopProvider);
    final current = _current(),
        locked =
            _busy || _picking || _needsCheck || _result != null || !current;
    final rows =
        _preview?.rows
            .where((row) => !_errorsOnly || row['kind'] == 'ERROR')
            .toList() ??
        [];
    return PopScope(
      canPop: !_busy && !_needsCheck,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _closing = true;
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 920,
          height: min(760, MediaQuery.sizeOf(context).height - 64),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nhập danh mục sản phẩm',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    featureGuideButton(context, 'product_import'),
                    IconButton(
                      onPressed: _busy ? null : _close,
                      tooltip: 'Đóng',
                      icon: const AppIcon(Icons.close),
                    ),
                  ],
                ),
                Text(_shopName),
                const SizedBox(height: 12),
                if (!current)
                  const Text(
                    'Tài khoản, cửa hàng hoặc quyền đã thay đổi. Đóng màn này và mở lại ở đúng cửa hàng.',
                  ),
                if (_busy) const LinearProgressIndicator(),
                if (_picking)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Đang chờ chọn tệp. Bạn vẫn có thể đóng màn hình này.',
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: rows.length + 1,
                    itemBuilder: (context, index) {
                      if (index > 0) return _row(rows[index - 1]);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Nhập file Excel .xlsx · Tối đa 500 sản phẩm, 5 MB. Chỉ nhập danh mục; không ghi tồn kho, thu chi hoặc công nợ.',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Chọn file hoặc tải mẫu để điền dữ liệu. Kiểm tra kết quả xem trước rồi xác nhận nhập.',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: locked ? null : _chooseFile,
                                icon: const AppIcon(
                                  Icons.upload_file_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _file?.name ?? 'Chọn file Excel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: locked || _downloadingTemplate
                                    ? null
                                    : _downloadTemplate,
                                icon: const AppIcon(
                                  Icons.download_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _downloadingTemplate
                                      ? 'Đang tải mẫu…'
                                      : 'Tải mẫu Excel',
                                ),
                              ),
                            ],
                          ),
                          if (_templateMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _templateMessage!,
                                style: TextStyle(
                                  color: _templateFailed
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                              ),
                            ),
                          if (_file?.isExcel == true) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'sheet-${_file!.sheetName}-$_error',
                              ),
                              initialValue: _file!.sheetName,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Sheet cần nhập',
                              ),
                              items: _file!.sheetNames
                                  .map(
                                    (name) => DropdownMenuItem(
                                      value: name,
                                      child: Text(name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: locked ? null : _selectSheet,
                            ),
                          ],
                          if (_inspection != null) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              key: ObjectKey(_inspection),
                              initialValue: _header!.line,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Dòng tiêu đề',
                              ),
                              items: _inspection!.candidates
                                  .map(
                                    (row) => DropdownMenuItem(
                                      value: row.line,
                                      child: Text(
                                        'Dòng ${row.line}: ${row.cells.join(' · ')}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: locked
                                  ? null
                                  : (line) => _changed(() {
                                      _header = _inspection!.candidates
                                          .firstWhere(
                                            (row) => row.line == line,
                                          );
                                      _columns = [..._header!.columns];
                                    }),
                            ),
                            const SizedBox(height: 12),
                            if (_file?.isExcel != true)
                              DropdownButtonFormField<String>(
                                initialValue: _numberFormat,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Định dạng số trong tệp',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'decimal-dot',
                                    child: Text('1234.50 — không phân nhóm'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'vi-VN',
                                    child: Text('1.234,50 — Việt Nam'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'en-US',
                                    child: Text('1,234.50 — Anh/Mỹ'),
                                  ),
                                ],
                                onChanged: locked
                                    ? null
                                    : (value) => _changed(
                                        () => _numberFormat = value!,
                                      ),
                              ),
                            const SizedBox(height: 12),
                            ExpansionTile(
                              key: ValueKey('import-mapping-${_header!.line}'),
                              title: const Text('Kiểm tra và gán cột'),
                              subtitle: Text(
                                '${_columns.whereType<String>().length}/${_columns.length} cột được nhập',
                              ),
                              tilePadding: EdgeInsets.zero,
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) => Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (var i = 0; i < _columns.length; i++)
                                        SizedBox(
                                          width: constraints.maxWidth < 520
                                              ? constraints.maxWidth
                                              : (constraints.maxWidth - 24) / 3,
                                          child: DropdownButtonFormField<String>(
                                            key: ValueKey(
                                              'import-column-${_header!.line}-$i-${_columns[i]}',
                                            ),
                                            initialValue: _columns[i] ?? '',
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                              labelText:
                                                  '${i + 1}. ${_header!.cells[i]}',
                                            ),
                                            items: [
                                              const DropdownMenuItem(
                                                value: '',
                                                child: Text(
                                                  'Không nhập cột này',
                                                ),
                                              ),
                                              ...productImportFields.entries
                                                  .map(
                                                    (field) => DropdownMenuItem(
                                                      value: field.key,
                                                      child: Text(field.value),
                                                    ),
                                                  ),
                                            ],
                                            onChanged: locked
                                                ? null
                                                : (value) => _changed(
                                                    () => _columns[i] =
                                                        value!.isEmpty
                                                        ? null
                                                        : value,
                                                  ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton(
                                onPressed: locked ? null : _loadPreview,
                                child: const Text('Xem trước'),
                              ),
                            ),
                          ],
                          if (_preview != null) ...[
                            const Divider(height: 28),
                            Text(
                              '${_preview!.total} dòng: ${_preview!.creates} mới · ${_preview!.updates} cập nhật · ${_preview!.unchanged} không đổi · ${_preview!.errors} lỗi',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_preview!.errors > 0)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Chỉ hiện dòng lỗi'),
                                value: _errorsOnly,
                                onChanged: (value) =>
                                    setState(() => _errorsOnly = value!),
                              ),
                            if (!_preview!.canCommit && _preview!.errors == 0)
                              const Text('Không có dữ liệu cần thay đổi.'),
                            const SizedBox(height: 8),
                          ],
                          if (_request != null)
                            SelectableText(
                              'Mã lượt nhập: ${_request!['operationId']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (_result != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Đã nhập: ${_result!.created} sản phẩm mới, ${_result!.updated} cập nhật; ${_result!.unchanged} không đổi.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : _close,
                      child: Text(_result == null ? 'Đóng' : 'Hoàn tất'),
                    ),
                    if (_needsCheck && _result == null)
                      OutlinedButton(
                        onPressed: _busy || !current ? null : _checkResult,
                        child: const Text('Kiểm tra kết quả'),
                      ),
                    if (_result == null)
                      FilledButton(
                        onPressed:
                            _busy ||
                                _picking ||
                                !current ||
                                _preview?.canCommit != true
                            ? null
                            : _commit,
                        child: Text(
                          _needsCheck ? 'Thử lại cùng lượt' : 'Xác nhận nhập',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> row) {
    const kinds = {
      'CREATE': 'Thêm mới',
      'UPDATE': 'Cập nhật',
      'UNCHANGED': 'Không đổi',
      'ERROR': 'Cần sửa',
    };
    String display(dynamic value) => value == null
        ? '—'
        : value is List
        ? value.join(' | ')
        : '$value';
    return ExpansionTile(
      key: ValueKey('import-row-${row['line']}'),
      title: Text('Dòng ${row['line']} · ${row['sku']}'),
      subtitle: Text(kinds[row['kind']]!),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final error in row['errors'] as List)
          Text(
            '$error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final change in row['changes'] as List)
          Text(
            '${change['label']}: ${display(change['before'])} → ${display(change['after'])}',
          ),
      ],
    );
  }
}
