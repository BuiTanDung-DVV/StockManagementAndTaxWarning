part of 'inventory_shelves_screen.dart';

typedef _ReadFloorResult = ({
  Map<String, _FloorObject> objects,
  int columns,
  int rows,
  String? warning,
});

_ReadFloorResult _readFloor(Object? raw) {
  final objects = <String, _FloorObject>{};
  var columns = 0;
  var rows = 0;
  String? warning;
  if (raw != null) {
    try {
      if (raw is! String) throw const FormatException();
      final decoded = jsonDecode(raw);
      final map = decoded is Map<String, dynamic> ? decoded : null;
      final list = map == null ? decoded : map['objects'];
      if (list is! List) throw const FormatException();

      int dimension(String key, int max) {
        final value = map?[key];
        if (value == null) return 0;
        if (value is int && value >= 0 && value <= max) return value;
        warning = 'Kích thước mặt bằng đã lưu bị lỗi.';
        return 0;
      }

      const max = _RackFloorState._maxGridSize;
      columns = dimension('extraColumns', max - _RackFloorState._baseColumns);
      rows = dimension('extraRows', max - _RackFloorState._baseRows);
      // Older versions only allowed moving fixtures within 60 rows. New
      // snapshots record the extent when an edit uses an automatically added row.
      final extent = map?['placedRows'] ?? max;
      final validExtent =
          extent is int &&
          extent >= max &&
          extent <= _RackFloorState._maxSavedRows;
      if (!validExtent) warning = 'Kích thước mặt bằng đã lưu bị lỗi.';
      final placedRows = validExtent ? extent : max;
      var skipped = 0;
      for (final entry in list) {
        try {
          final item = _FloorObject.fromJson(entry as Map<String, dynamic>);
          final b = item.block;
          if (objects.containsKey(item.id) ||
              (b != null &&
                  (b.column < 0 ||
                      b.row < 0 ||
                      b.columns < 1 ||
                      b.rows < 1 ||
                      b.column + b.columns > max ||
                      b.row + b.rows > placedRows))) {
            throw const FormatException();
          }
          objects[item.id] = item;
        } on Object {
          skipped++;
        }
      }
      if (skipped > 0) warning = 'Không đọc được $skipped vật thể đã lưu.';
    } on FormatException {
      warning = 'Không đọc được bố trí đã lưu trên thiết bị.';
    }
  }
  return (objects: objects, columns: columns, rows: rows, warning: warning);
}

String _encodeFloor(Map<String, _FloorObject> objects, int columns, int rows) {
  if (objects.isEmpty && columns == 0 && rows == 0) return '[]';
  final extent = objects.values.fold(_RackFloorState._maxGridSize, (end, item) {
    final block = item.block;
    return block == null ? end : math.max(end, block.row + block.rows);
  });
  return jsonEncode({
    'objects': objects.values.toList(),
    'extraColumns': columns,
    'extraRows': rows,
    if (extent > _RackFloorState._maxGridSize) 'placedRows': extent,
  });
}
