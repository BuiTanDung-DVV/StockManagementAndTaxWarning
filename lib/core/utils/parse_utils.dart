double parseCurrency(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is! String) return fallback;

  var text = value.trim();
  if (text.isEmpty) return fallback;

  // Remove currency symbols and spaces
  text = text
      .replaceAll('₫', '')
      .replaceAll('VND', '')
      .replaceAll('vnd', '')
      .replaceAll('đ', '')
      .replaceAll(' ', '')
      .trim();

  // Pattern: Vietnamese thousands dot (e.g. '150.000', '1.500.000')
  if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(text)) {
    return double.tryParse(text.replaceAll('.', '')) ?? fallback;
  }

  // Pattern: Comma separated thousands (e.g. '150,000', '1,500,000')
  if (RegExp(r'^-?\d{1,3}(,\d{3})+$').hasMatch(text)) {
    return double.tryParse(text.replaceAll(',', '')) ?? fallback;
  }

  // Mixed format: '1,500,000.50' (thousands comma, decimal dot)
  if (RegExp(r'^-?\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(text)) {
    return double.tryParse(text.replaceAll(',', '')) ?? fallback;
  }

  // Mixed format: '1.500.000,50' (thousands dot, decimal comma)
  if (RegExp(r'^-?\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(text)) {
    return double.tryParse(text.replaceAll('.', '').replaceAll(',', '.')) ??
        fallback;
  }

  // Standard numeric fallback
  final clean = text.replaceAll(',', '');
  return double.tryParse(clean) ?? fallback;
}

double parseQuantity(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is! String) return fallback;
  final text = value.trim();
  if (text.isEmpty) return fallback;
  final normalized = text.replaceAll(' ', '').replaceAll(',', '.');
  return double.tryParse(normalized) ?? fallback;
}

num asNum(dynamic value, {num fallback = 0}) {
  if (value is num) return value;
  if (value is String) {
    return parseCurrency(value, fallback: fallback.toDouble());
  }
  return fallback;
}

double asDouble(dynamic value, {double fallback = 0}) {
  return asNum(value, fallback: fallback).toDouble();
}

int asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return asNum(value, fallback: fallback).toInt();
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  if (value is Map && value.isNotEmpty) return [value];
  return const [];
}
