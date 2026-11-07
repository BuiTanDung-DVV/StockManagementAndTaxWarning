class InvoicePurchaseSource {
  final int scanId, invoiceId, shopId;
  final String number, revision, partnerName, invoiceDate;
  final double total, subtotal;
  final List<Map<String, dynamic>> items;
  const InvoicePurchaseSource({
    required this.scanId,
    required this.invoiceId,
    required this.shopId,
    required this.number,
    required this.revision,
    required this.partnerName,
    required this.invoiceDate,
    required this.total,
    required this.subtotal,
    required this.items,
  });

  factory InvoicePurchaseSource.fromScan(Map<String, dynamic> scan) {
    final invoice = Map<String, dynamic>.from(scan['invoice'] as Map);
    final data = Map<String, dynamic>.from(scan['editableData'] as Map);
    return InvoicePurchaseSource(
      scanId: (scan['id'] as num).toInt(),
      invoiceId: (invoice['id'] as num).toInt(),
      shopId: (invoice['shopId'] as num).toInt(),
      number: '${data['invoiceNumber']}',
      revision: '${scan['invoiceRevision']}',
      partnerName: '${data['partnerName']}',
      invoiceDate: '${data['invoiceDate']}',
      total: double.parse('${data['totalAmount']}'),
      subtotal: double.parse('${data['subtotal']}'),
      items: (data['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }

  /// Suggested inventory cost distributes the document total; the user verifies it.
  List<Map<String, dynamic>> suggestedRows() => items.map((item) {
    final qty = double.parse('${item['quantity']}');
    final price = double.parse('${item['unitPrice']}');
    return <String, dynamic>{
      'productName': item['itemName'],
      'sourceLabel':
          '${item['itemName']} · ${item['quantity']} ${item['unit']}',
      'quantityText': qty == qty.roundToDouble() ? '${qty.toInt()}' : '$qty',
      'priceText': (subtotal > 0 ? price * total / subtotal : price)
          .toStringAsFixed(2),
    };
  }).toList();
}
