class ReplenishmentLine {
  final int productId;
  final String name;
  final String sku;
  final String unit;
  final String imageUrl;
  final double stock;
  final double minimum;
  final int quantity;
  const ReplenishmentLine({
    required this.productId,
    required this.name,
    required this.sku,
    required this.unit,
    required this.imageUrl,
    required this.stock,
    required this.minimum,
    required this.quantity,
  });

  static ReplenishmentLine? from(dynamic row, int shopId) {
    if (row is! Map || row['product'] is! Map) return null;
    final product = row['product'] as Map;
    final sourceShop = int.tryParse('${row['shopId']}');
    final id = int.tryParse('${row['productId'] ?? product['id']}');
    final stock = double.tryParse(
      '${row['currentQuantity'] ?? row['quantity']}',
    );
    final minimum = double.tryParse(
      '${row['minStock'] ?? product['minStock']}',
    );
    if ((sourceShop != null && sourceShop != shopId) ||
        id == null ||
        id <= 0 ||
        stock == null ||
        minimum == null ||
        !stock.isFinite ||
        !minimum.isFinite ||
        minimum <= 0 ||
        stock < 0 ||
        stock >= minimum) {
      return null;
    }
    final difference = minimum - stock;
    if (!difference.isFinite || difference > 1000000000000000) return null;
    final gap = difference.ceil();
    return ReplenishmentLine(
      productId: id,
      name: '${product['name'] ?? 'Sản phẩm'}',
      sku: '${product['sku'] ?? ''}',
      unit: '${product['unit'] ?? ''}',
      imageUrl: '${product['imageUrl'] ?? ''}',
      stock: stock,
      minimum: minimum,
      quantity: gap > 0 ? gap : 1,
    );
  }

  ReplenishmentLine withQuantity(int value) => ReplenishmentLine(
    productId: productId,
    name: name,
    sku: sku,
    unit: unit,
    imageUrl: imageUrl,
    stock: stock,
    minimum: minimum,
    quantity: value,
  );
}

class PurchaseOrderSuggestion {
  final int userId;
  final int shopId;
  final List<ReplenishmentLine> items;
  PurchaseOrderSuggestion({
    required this.userId,
    required this.shopId,
    required List<ReplenishmentLine> items,
  }) : items = List.unmodifiable(items) {
    if (userId <= 0 ||
        shopId <= 0 ||
        items.isEmpty ||
        items.any(
          (i) =>
              i.productId <= 0 ||
              i.quantity <= 0 ||
              i.quantity > 1000000000000000,
        ) ||
        items.map((i) => i.productId).toSet().length != items.length) {
      throw ArgumentError('Đề xuất nhập hàng không hợp lệ.');
    }
  }
  bool matches(int user, int shop) => userId == user && shopId == shop;

  /// Keep intentional quantities/prices. A repeated suggestion must not add
  /// the same product quantity twice to an existing draft.
  List<Map<String, dynamic>> merge(
    List<dynamic> existing,
    List<dynamic> products,
  ) {
    final catalog = {
      for (final product in products.whereType<Map>())
        int.tryParse('${product['id']}'): product,
    };
    final result = existing
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    for (final item in items) {
      final product = catalog[item.productId];
      if (product == null) {
        throw StateError(
          'Sản phẩm ${item.name} không còn trong danh mục đang dùng. Tải lại đề xuất.',
        );
      }
      final index = result.indexWhere(
        (row) => '${row['productId']}' == '${item.productId}',
      );
      if (index >= 0) {
        final quantity = int.tryParse('${result[index]['quantityText']}');
        if (quantity == null || quantity <= 0) {
          throw StateError(
            'Sửa số lượng đang nhập của ${item.name} trước khi thêm đề xuất.',
          );
        }
        if (item.quantity > quantity) {
          result[index]['quantityText'] = '${item.quantity}';
        }
      } else {
        final cost = num.tryParse('${product['costPrice']}');
        result.add({
          'productId': item.productId,
          'productName': '${product['name'] ?? item.name}',
          'productSku': '${product['sku'] ?? item.sku}',
          'quantityText': '${item.quantity}',
          'priceText': cost != null && cost.isFinite && cost > 0 ? '$cost' : '',
        });
      }
    }
    return result;
  }
}
