String warehouseDisplayName(Object? name) {
  final label = name?.toString().trim() ?? '';
  final cleaned = label
      .replaceFirst(
        RegExp(r'\s*·\s*(?:[A-Z]\s*·\s*)?STORE_HISTORY_[A-Z0-9_]+$'),
        '',
      )
      .trim();
  return cleaned.isEmpty ? 'Kho' : cleaned;
}
