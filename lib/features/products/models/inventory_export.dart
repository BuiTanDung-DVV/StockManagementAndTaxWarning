import '../../finance/models/cash_ledger_export.dart';

class InventoryExportRow {
  final int id;
  final String sku, name, unit;
  final int? stock, minStock, priceCents;
  final List<String> tags;
  const InventoryExportRow(
    this.id,
    this.sku,
    this.name,
    this.unit,
    this.stock,
    this.minStock,
    this.priceCents,
    this.tags,
  );
  String get status {
    if (stock == null) return 'Chưa có số liệu tồn';
    if (stock! < 0) return 'Tồn âm – cần đối chiếu';
    if (stock == 0) return 'Hết hàng';
    if (minStock == null) return 'Chưa có định mức';
    if (minStock == 0) return 'Chưa đặt định mức';
    return stock! <= minStock! ? 'Cần nhập thêm' : 'Đủ theo định mức';
  }
}

class InventoryExport {
  final int shopId, matchingCount;
  final DateTime generatedAt;
  final Map<String, dynamic> filters;
  final List<InventoryExportRow> items;
  final String selection;
  const InventoryExport._(
    this.shopId,
    this.generatedAt,
    this.filters,
    this.items,
    this.matchingCount,
    this.selection,
  );
  static Never _invalid() => throw const FormatException(
    'Dữ liệu xuất tồn kho thiếu, sai số hoặc không khớp phạm vi.',
  );
  static int? _quantity(dynamic value, {bool negative = false}) {
    if (value == null) return null;
    if (value is bool || !RegExp(r'^-?\d+$').hasMatch('$value')) _invalid();
    final result = int.tryParse('$value');
    if (result == null ||
        result.abs() > 999999999999999 ||
        (!negative && result < 0)) {
      _invalid();
    }
    return result;
  }

  factory InventoryExport.fromResponse(
    dynamic raw, {
    required int shopId,
    String? search,
    String? tag,
    int? categoryId,
    bool inStockOnly = false,
  }) {
    String? text(String? s) => s?.trim().isEmpty == false ? s!.trim() : null;
    final expected = {
      'search': text(search),
      'tag': text(tag),
      'categoryId': categoryId,
      'inStockOnly': inStockOnly,
    };
    if (shopId <= 0 ||
        raw is! Map ||
        raw['shopId'] != shopId ||
        raw['filters'] is! Map ||
        raw['items'] is! List ||
        raw['total'] is! int) {
      _invalid();
    }
    for (final key in expected.keys) {
      if (raw['filters'][key] != expected[key]) _invalid();
    }
    final timestamp = raw['generatedAt'];
    if (timestamp is! String ||
        timestamp.length < 10 ||
        !CashLedgerExport.validDate(timestamp.substring(0, 10)) ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(timestamp)) {
      _invalid();
    }
    final at = DateTime.tryParse(timestamp);
    if (at == null) _invalid();
    final rows = <InventoryExportRow>[], ids = <int>{};
    for (final row in raw['items'] as List) {
      if (row is! Map ||
          row['id'] is! int ||
          row['id'] <= 0 ||
          !ids.add(row['id']) ||
          row['shopId'] != shopId ||
          ['sku', 'name', 'unit'].any(
            (key) => row[key] is! String || (row[key] as String).trim().isEmpty,
          )) {
        _invalid();
      }
      final rawTags = row['tags'];
      final List<dynamic> tags = rawTags == null
          ? []
          : rawTags is String
          ? rawTags.split(',')
          : rawTags is List
          ? rawTags
          : _invalid();
      if (tags.any((t) => t is! String)) _invalid();
      rows.add(
        InventoryExportRow(
          row['id'],
          row['sku'],
          row['name'],
          row['unit'],
          _quantity(row['currentStock'], negative: true),
          _quantity(row['minStock']),
          row['sellingPrice'] == null
              ? null
              : CashLedgerExport.cents(row['sellingPrice']),
          List.unmodifiable(
            tags
                .cast<String>()
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toSet(),
          ),
        ),
      );
    }
    if (raw['total'] != rows.length) _invalid();
    return InventoryExport._(
      shopId,
      at,
      Map.unmodifiable(expected),
      List.unmodifiable(rows),
      rows.length,
      'Tất cả kết quả lọc',
    );
  }
  InventoryExport select({
    required bool allFiltered,
    required Set<int> selectedIds,
    required Set<int> excludedIds,
  }) {
    final selected = items
        .where(
          (row) => allFiltered
              ? !excludedIds.contains(row.id)
              : selectedIds.contains(row.id),
        )
        .toList();
    if (!allFiltered && selected.length != selectedIds.length) _invalid();
    return InventoryExport._(
      shopId,
      generatedAt,
      filters,
      List.unmodifiable(selected),
      matchingCount,
      allFiltered
          ? 'Tất cả kết quả lọc; bỏ chọn ${items.length - selected.length}'
          : 'Chọn riêng ${selected.length} sản phẩm',
    );
  }
}
