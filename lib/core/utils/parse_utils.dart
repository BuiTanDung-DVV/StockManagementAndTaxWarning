num asNum(dynamic value, {num fallback = 0}) {
  if (value is num) return value;
  if (value is String) {
    final normalized = value.replaceAll(',', '').trim();
    return num.tryParse(normalized) ?? fallback;
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
