class ClosingCashAssessment {
  const ClosingCashAssessment({
    required this.actualCash,
    required this.difference,
    required this.needsExplanation,
  });

  final double? actualCash;
  final double? difference;
  final bool needsExplanation;

  bool get canSubmit => actualCash != null;
}

ClosingCashAssessment assessClosingCash({
  required String rawActualCash,
  required double expectedCash,
}) {
  final normalized = rawActualCash.trim();
  final parsed = normalized.isEmpty ? null : double.tryParse(normalized);
  final actualCash = parsed != null && parsed >= 0 ? parsed : null;
  final difference = actualCash == null ? null : actualCash - expectedCash;

  return ClosingCashAssessment(
    actualCash: actualCash,
    difference: difference,
    needsExplanation: difference != null && difference.abs() > 50000,
  );
}
