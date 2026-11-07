import 'dart:convert';
import 'dart:typed_data';
import 'product_import_excel.dart';

const productImportTemplateAsset = 'assets/templates/Mau_nhap_san_pham.xlsx';
const productImportTemplateFileName = 'Mau_nhap_san_pham.xlsx';

const productImportFields = <String, String>{
  'sku': 'SKU',
  'name': 'Tên sản phẩm',
  'unit': 'Đơn vị',
  'costPrice': 'Giá nhập',
  'sellingPrice': 'Giá bán',
  'wholesalePrice': 'Giá bán sỉ',
  'minStock': 'Mức tối thiểu',
  'barcode': 'Mã vạch',
  'categoryName': 'Danh mục',
  'tags': 'Nhãn',
  'description': 'Mô tả',
};

class ProductImportFile {
  final String name;
  final String csv;
  final ProductImportWorkbook? _workbook;
  final String? sheetName;
  ProductImportFile._(this.name, this.csv, this._workbook, this.sheetName);
  factory ProductImportFile.fromBytes(String name, Uint8List bytes) {
    if (name.toLowerCase().endsWith('.xlsx')) {
      final workbook = ProductImportWorkbook.fromBytes(bytes);
      final selected = workbook.defaultSheet;
      return ProductImportFile._(
        name,
        workbook.csvForSheet(selected),
        workbook,
        selected,
      );
    }
    return ProductImportFile._(name, _decode(name, bytes), null, null);
  }
  bool get isExcel => _workbook != null;
  List<String> get sheetNames => _workbook?.sheets ?? const [];
  ProductImportFile selectSheet(String selected) {
    if (_workbook == null) {
      throw const FormatException('File không có sheet Excel.');
    }
    return ProductImportFile._(
      name,
      _workbook.csvForSheet(selected),
      _workbook,
      selected,
    );
  }

  static String _decode(String name, Uint8List bytes) {
    if (!name.toLowerCase().endsWith('.csv')) {
      throw const FormatException(
        'Chọn file Excel .xlsx. Với file .xls cũ, hãy lưu lại thành .xlsx.',
      );
    }
    if (bytes.isEmpty || bytes.length > 1024 * 1024) {
      throw const FormatException(
        'Tệp phải có dữ liệu và không vượt quá 1 MB.',
      );
    }
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const FormatException(
        'Tệp chưa đúng UTF-8. Hãy lưu lại bằng CSV UTF-8 trong Excel.',
      );
    }
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) {
    throw const FormatException('Phản hồi nhập tệp không hợp lệ.');
  }
  return Map<String, dynamic>.from(value);
}

int _count(dynamic value, {int maximum = 500}) {
  if (value is! int || value < 0 || value > maximum) {
    throw const FormatException('Số dòng phản hồi không hợp lệ.');
  }
  return value;
}

class ProductImportHeader {
  final int line;
  final List<String> cells;
  final List<String?> columns;
  ProductImportHeader.fromJson(dynamic json)
    : line = _count(_map(json)['line'], maximum: 1000000),
      cells = List<String>.from(_map(json)['cells'] as List),
      columns = List<String?>.from(_map(json)['columns'] as List) {
    if (line < 1 ||
        cells.isEmpty ||
        cells.length > 64 ||
        columns.length != cells.length ||
        columns.any(
          (value) => value != null && !productImportFields.containsKey(value),
        )) {
      throw const FormatException('Dòng tiêu đề không hợp lệ.');
    }
  }
}

class ProductImportInspection {
  final List<ProductImportHeader> candidates;
  final int defaultHeaderLine;
  ProductImportInspection.fromJson(dynamic json)
    : candidates = (_map(json)['candidates'] as List)
          .map(ProductImportHeader.fromJson)
          .toList(),
      defaultHeaderLine = _count(
        _map(json)['defaultHeaderLine'],
        maximum: 1000000,
      ) {
    if (candidates.isEmpty ||
        candidates.length > 10 ||
        !candidates.any((header) => header.line == defaultHeaderLine) ||
        candidates.map((header) => header.line).toSet().length !=
            candidates.length) {
      throw const FormatException('Không đọc được tiêu đề tệp.');
    }
  }
}

class ProductImportPreview {
  final int shopId;
  final String planHash;
  final Map<String, int> summary;
  final List<Map<String, dynamic>> rows;
  ProductImportPreview.fromJson(dynamic json, int expectedShop)
    : shopId = _map(json)['shopId'] as int,
      planHash = _map(json)['planHash'] as String,
      summary = _map(
        _map(json)['summary'],
      ).map((key, value) => MapEntry(key, _count(value))),
      rows = (_map(json)['rows'] as List).map(_map).toList() {
    if (shopId != expectedShop ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(planHash) ||
        _map(json)['writesApplied'] != false ||
        rows.isEmpty ||
        rows.length > 500 ||
        summary['total'] != rows.length) {
      throw const FormatException(
        'Phản hồi xem trước sai phạm vi hoặc số dòng.',
      );
    }
    const kinds = {
      'CREATE': 'create',
      'UPDATE': 'update',
      'UNCHANGED': 'unchanged',
      'ERROR': 'errors',
    };
    for (final kind in kinds.entries) {
      if (rows.where((row) => row['kind'] == kind.key).length !=
          summary[kind.value]) {
        throw const FormatException('Kết quả phân loại dòng không khớp.');
      }
    }
    for (final row in rows) {
      if (!kinds.containsKey(row['kind']) ||
          row['sku'] is! String ||
          row['line'] is! int ||
          (row['line'] as int) < 1 ||
          row['changes'] is! List ||
          row['errors'] is! List ||
          (row['kind'] == 'ERROR') != (row['errors'] as List).isNotEmpty ||
          (row['changes'] as List).any(
            (change) =>
                change is! Map ||
                change['label'] is! String ||
                !change.containsKey('before') ||
                !change.containsKey('after'),
          )) {
        throw const FormatException('Chi tiết dòng nhập không hợp lệ.');
      }
    }
  }
  int get total => summary['total']!;
  int get creates => summary['create']!;
  int get updates => summary['update']!;
  int get unchanged => summary['unchanged']!;
  int get errors => summary['errors']!;
  bool get canCommit => errors == 0 && creates + updates > 0;
}

class ProductImportResult {
  final int total, created, updated, unchanged;
  final bool replayed;
  ProductImportResult.fromJson(dynamic json, int shopId, String operationId)
    : total = _count(_map(json)['total']),
      created = _count(_map(json)['created']),
      updated = _count(_map(json)['updated']),
      unchanged = _count(_map(json)['unchanged']),
      replayed = _map(json)['replayed'] as bool {
    if (_map(json)['shopId'] != shopId ||
        _map(json)['operationId'] != operationId ||
        total != created + updated + unchanged) {
      throw const FormatException('Kết quả nhập sai phạm vi hoặc số dòng.');
    }
  }
}
