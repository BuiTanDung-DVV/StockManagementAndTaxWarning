/// Display-only balance. The server validates and records monetary operations.
double customerReceivableRemaining(Map<String, dynamic> debt) {
  if (debt['openingEffective'] == false ||
      debt['status']?.toString().toUpperCase() == 'CANCELLED') {
    return 0;
  }
  final raw = debt['remaining'] ?? debt['remainingAmount'];
  final authoritative = num.tryParse(raw?.toString() ?? '');
  if (authoritative != null && authoritative.isFinite && authoritative >= 0) {
    return authoritative.toDouble();
  }
  // Older responses have no effective balance fields.
  if (raw == null && debt['status']?.toString().toUpperCase() == 'PAID') {
    return 0;
  }
  double value(dynamic input) {
    final parsed = num.tryParse(input?.toString() ?? '0');
    return parsed != null && parsed.isFinite ? parsed.toDouble() : 0;
  }

  return (value(debt['totalAmount'] ?? debt['amount']) -
          value(debt['paidAmount']) +
          value(debt['openingAdjustmentAmount']))
      .clamp(0, double.infinity)
      .toDouble();
}
