class XntExport {
  final int shopId;
  final String from, to;
  final int? warehouseId;
  final List<Map<String, dynamic>> items;
  final Map<String, int> summary;
  XntExport._(
    this.shopId,
    this.from,
    this.to,
    this.warehouseId,
    this.items,
    this.summary,
  );

  static bool _date(String value) {
    final date = DateTime.tryParse(value);
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
        date != null &&
        date.toIso8601String().startsWith(value);
  }

  static int _integer(dynamic value) {
    if (value is! int || value.abs() > 9007199254740991) {
      throw const FormatException('Số lượng XNT không hợp lệ.');
    }
    return value;
  }

  factory XntExport.fromResponse(
    dynamic json, {
    required int shopId,
    required String from,
    required String to,
    int? warehouseId,
  }) {
    if (json is! Map ||
        shopId <= 0 ||
        !_date(from) ||
        !_date(to) ||
        from.compareTo(to) > 0 ||
        json['shopId'] != shopId ||
        json['warehouseId'] != warehouseId ||
        json['period'] is! Map ||
        json['period']['from'] != from ||
        json['period']['to'] != to ||
        json['period']['dateField'] != 'movementBusinessDate' ||
        json['items'] is! List ||
        json['summary'] is! Map) {
      throw const FormatException(
        'Báo cáo XNT không khớp cửa hàng, kho hoặc kỳ đang chọn.',
      );
    }
    final rows = <Map<String, dynamic>>[], ids = <int>{};
    final summary = {
      'recordCount': (json['items'] as List).length,
      'openingSkuCount': 0,
      'importedSkuCount': 0,
      'exportedSkuCount': 0,
      'closingSkuCount': 0,
    };
    for (final raw in json['items'] as List) {
      if (raw is! Map) throw const FormatException('Dòng XNT không hợp lệ.');
      final row = Map<String, dynamic>.from(raw), id = _integer(raw['id']);
      if (id <= 0 ||
          !ids.add(id) ||
          ['sku', 'name', 'unit'].any(
            (field) =>
                row[field] is! String || (row[field] as String).trim().isEmpty,
          )) {
        throw const FormatException(
          'Thiếu hoặc trùng sản phẩm trong báo cáo XNT.',
        );
      }
      final opening = _integer(row['openingStock']),
          imported = _integer(row['totalImport']),
          exported = _integer(row['totalExport']),
          closing = _integer(row['closingStock']);
      if (imported < 0 ||
          exported < 0 ||
          (opening + imported).abs() > 9007199254740991 ||
          opening + imported - exported != closing) {
        throw const FormatException(
          'Số tồn đầu + nhập − xuất chưa khớp tồn cuối.',
        );
      }
      if (opening > 0) {
        summary['openingSkuCount'] = summary['openingSkuCount']! + 1;
      }
      if (imported > 0) {
        summary['importedSkuCount'] = summary['importedSkuCount']! + 1;
      }
      if (exported > 0) {
        summary['exportedSkuCount'] = summary['exportedSkuCount']! + 1;
      }
      if (closing > 0) {
        summary['closingSkuCount'] = summary['closingSkuCount']! + 1;
      }
      rows.add(Map.unmodifiable(row));
    }
    for (final entry in summary.entries) {
      if (json['summary'][entry.key] != entry.value) {
        throw const FormatException('Tổng SKU không khớp các dòng XNT.');
      }
    }
    return XntExport._(
      shopId,
      from,
      to,
      warehouseId,
      List.unmodifiable(rows),
      Map.unmodifiable(summary),
    );
  }
}
