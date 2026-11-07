/// Shared defaults for the editor and the actual printed receipt.
class ReceiptTemplateConfig {
  static const flags = {
    'showLogo': 'Logo',
    'showShopInfo': 'Thông tin cửa hàng',
    'showCustomer': 'Khách hàng',
    'showSku': 'Mã SKU',
    'showUnit': 'Đơn vị tính',
    'showItemNumber': 'Số thứ tự hàng',
    'showDiscount': 'Chiết khấu',
    'showTax': 'Dòng tiền thuế',
    'showShipping': 'Phí giao hàng',
    'showPayment': 'Tiền đã thanh toán',
    'showBalance': 'Số tiền còn phải thu',
    'showNote': 'Ghi chú đơn hàng',
    'showQr': 'QR của cửa hàng',
    'showFooter': 'Lời nhắn cuối phiếu',
  };

  static const ranges = <String, List<double>>{
    'fontSize': [7, 13],
    'titleSize': [12, 24],
    'lineSpacing': [0, 5],
    'marginMm': [2, 15],
    'logoWidthMm': [10, 50],
    'logoHeightMm': [8, 35],
    'qrSizeMm': [20, 45],
  };

  static Map<String, dynamic> normalize(Map<String, dynamic> raw) {
    final a4 = raw['paperSize'] == 'A4';
    final defaults = <String, dynamic>{
      'paperSize': a4 ? 'A4' : '80mm',
      'preset': 'standard',
      'title': 'PHIẾU BÁN HÀNG',
      'footer': '',
      'logoSource': 'shop',
      'logoUrl': '',
      'logoPosition': 'center',
      'headerAlignment': 'center',
      'footerAlignment': 'center',
      'fontFamily': 'noto',
      'fontSize': a4 ? 10.0 : 8.5,
      'titleSize': a4 ? 18.0 : 12.0,
      'lineSpacing': 1.0,
      'marginMm': a4 ? 10.0 : 3.5,
      'logoWidthMm': 20.0,
      'logoHeightMm': 18.0,
      'qrSizeMm': 30.0,
      for (final key in flags.keys)
        key: !const {'showItemNumber', 'showBalance', 'showNote'}.contains(key),
    };
    final result = <String, dynamic>{...defaults};
    for (final entry in defaults.entries) {
      final value = raw[entry.key];
      if (value == null) continue;
      if (entry.value is bool && value is bool) result[entry.key] = value;
      if (entry.value is String && value is String) result[entry.key] = value;
      if (entry.value is double && value is num && value.isFinite) {
        final range = ranges[entry.key]!;
        result[entry.key] = value.toDouble().clamp(range[0], range[1]);
      }
    }
    for (final entry in <String, Set<String>>{
      'paperSize': {'80mm', 'A4'},
      'preset': {'compact', 'standard', 'detailed'},
      'logoSource': {'shop', 'custom', 'none'},
      'logoPosition': {'left', 'center', 'right'},
      'headerAlignment': {'left', 'center', 'right'},
      'footerAlignment': {'left', 'center', 'right'},
      'fontFamily': {'noto', 'inter'},
    }.entries) {
      if (!entry.value.contains(result[entry.key])) {
        result[entry.key] = defaults[entry.key];
      }
    }
    return result;
  }

  /// Presets change presentation, preserving the shop's wording and logo.
  static Map<String, dynamic> applyPreset(
    Map<String, dynamic> current,
    String preset,
  ) {
    final a4 = current['paperSize'] == 'A4';
    return normalize({
      ...current,
      'preset': preset,
      'fontSize': preset == 'compact' ? (a4 ? 9.0 : 8.0) : (a4 ? 10.0 : 8.5),
      'titleSize': a4 ? 18.0 : 12.0,
      'lineSpacing': preset == 'compact'
          ? 0.0
          : (preset == 'detailed' ? 2.0 : 1.0),
      'marginMm': a4 ? 10.0 : 3.5,
      for (final key in ['showSku', 'showUnit', 'showCustomer'])
        key: preset != 'compact',
      for (final key in ['showItemNumber', 'showBalance', 'showNote'])
        key: preset == 'detailed',
    });
  }
}
