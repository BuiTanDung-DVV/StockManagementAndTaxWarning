/// Collect an explicitly complete option set. Overlapping pages or a changed
/// count are errors, never a silently truncated selector/export.
Future<Map<String, dynamic>> collectPagedRecords(
  Future<dynamic> Function(int page, int limit) load, {
  required bool Function() isCurrent,
  int pageSize = 200,
  int maxRecords = 50000,
  void Function(int loaded, int total)? onProgress,
}) async {
  final items = <Map<String, dynamic>>[];
  final ids = <int>{};
  int? expected;
  for (var page = 1; ; page++) {
    if (!isCurrent()) throw StateError('Phạm vi dữ liệu đã thay đổi.');
    final data = await load(page, pageSize);
    if (!isCurrent()) throw StateError('Phạm vi dữ liệu đã thay đổi.');
    if (data is! Map ||
        data['items'] is! List ||
        data['total'] is! num ||
        data['total'] != (data['total'] as num).toInt() ||
        data['total'] < 0 ||
        (data['page'] != null && data['page'] != page)) {
      throw StateError('Máy chủ trả danh sách không đầy đủ.');
    }
    final total = (data['total'] as num).toInt();
    if (total > maxRecords) {
      throw StateError(
        'Danh mục vượt giới hạn tải $maxRecords dòng. Chưa lưu bản đầy đủ.',
      );
    }
    if (expected != null && expected != total) {
      throw StateError('Danh mục thay đổi trong khi tải. Hãy thử lại.');
    }
    expected = total;
    final rows = data['items'] as List;
    for (final row in rows) {
      final id = row is Map ? int.tryParse('${row['id']}') : null;
      if (id == null || id <= 0 || !ids.add(id)) {
        throw StateError('Danh mục có dòng thiếu mã hoặc lặp giữa các trang.');
      }
      items.add({...Map<String, dynamic>.from(row as Map), 'id': id});
    }
    if (items.length > total || (rows.isEmpty && items.length < total)) {
      throw StateError('Không tải đủ danh mục.');
    }
    onProgress?.call(items.length, total);
    if (items.length == total) {
      return {
        'items': items,
        'total': total,
        'page': 1,
        'limit': total == 0 ? pageSize : total,
        'totalPages': total == 0 ? 0 : 1,
      };
    }
  }
}
