import 'purchase_order_suggestion.dart';

/// A pending purchase is a warning, not a reservation or confirmed receipt.
class PendingPurchaseMatch {
  final int orderId;
  final String orderCode;
  final String productName;
  final int quantity;

  const PendingPurchaseMatch({
    required this.orderId,
    required this.orderCode,
    required this.productName,
    required this.quantity,
  });
}

Future<List<PendingPurchaseMatch>> checkReplenishmentSafety({
  required int shopId,
  required List<ReplenishmentLine> selected,
  required Future<List<dynamic>> Function() loadStock,
  required Future<Map<String, dynamic>> Function(int page) loadPendingPage,
  required bool Function() isCurrentScope,
}) async {
  void guard() {
    if (!isCurrentScope()) {
      throw StateError('Tài khoản hoặc cửa hàng đã thay đổi. Mở lại đề xuất.');
    }
  }

  guard();
  final fresh = await loadStock();
  guard();
  final current = <int, ReplenishmentLine>{};
  for (final row in fresh) {
    final item = ReplenishmentLine.from(row, shopId);
    if (item != null) current[item.productId] = item;
  }
  for (final item in selected) {
    final latest = current[item.productId];
    if (latest == null ||
        latest.stock != item.stock ||
        latest.minimum != item.minimum) {
      throw StateError(
        'Tồn kho hoặc định mức của ${item.name} đã thay đổi. Đóng và mở lại đề xuất để kiểm tra số lượng mới.',
      );
    }
  }

  final selectedById = {for (final item in selected) item.productId: item};
  final matches = <PendingPurchaseMatch>[];
  final seen = <int>{};
  int? expectedTotal;
  for (var page = 1; page <= 20; page++) {
    guard();
    final data = await loadPendingPage(page);
    guard();
    final rows = data['items'];
    final total = int.tryParse('${data['total']}');
    final pages = int.tryParse('${data['totalPages']}');
    if (rows is! List ||
        total == null ||
        total < 0 ||
        pages == null ||
        pages < 0 ||
        pages > 20 ||
        (expectedTotal != null && expectedTotal != total) ||
        (total > 0 && pages == 0) ||
        (page < pages && rows.isEmpty)) {
      throw StateError(
        'Chưa kiểm tra đủ phiếu nhập chờ. Thử lại hoặc vào Đơn nhập hàng để kiểm tra.',
      );
    }
    expectedTotal = total;
    for (final row in rows) {
      if (row is! Map ||
          '${row['shopId']}' != '$shopId' ||
          row['status'] != 'PENDING') {
        throw StateError('Dữ liệu phiếu nhập chờ không đúng phạm vi. Thử lại.');
      }
      final id = int.tryParse('${row['id']}');
      final lines = row['items'];
      final code = '${row['orderCode'] ?? ''}'.trim();
      if (id == null ||
          id <= 0 ||
          !seen.add(id) ||
          lines is! List ||
          lines.isEmpty ||
          code.isEmpty) {
        throw StateError(
          'Danh sách phiếu nhập chờ đã thay đổi hoặc thiếu thông tin. Thử lại.',
        );
      }
      for (final line in lines) {
        if (line is! Map) throw StateError('Thiếu dòng hàng của phiếu $code.');
        final productId = int.tryParse(
          '${line['productId'] ?? (line['product'] is Map ? line['product']['id'] : null)}',
        );
        final quantity = int.tryParse('${line['quantity']}');
        if (productId == null || quantity == null || quantity <= 0) {
          throw StateError('Dòng hàng của phiếu $code không hợp lệ.');
        }
        final selectedItem = selectedById[productId];
        if (selectedItem != null) {
          matches.add(
            PendingPurchaseMatch(
              orderId: id,
              orderCode: code,
              productName: selectedItem.name,
              quantity: quantity,
            ),
          );
        }
      }
    }
    if (page >= pages) {
      if (seen.length != total) {
        throw StateError('Chưa kiểm tra đủ phiếu nhập chờ. Thử lại.');
      }
      return matches;
    }
  }
  throw StateError(
    'Có quá nhiều phiếu nhập chờ. Kiểm tra tại Đơn nhập hàng trước khi lập phiếu mới.',
  );
}
