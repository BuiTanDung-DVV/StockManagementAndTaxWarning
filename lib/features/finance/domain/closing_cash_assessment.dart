import '../../../core/utils/parse_utils.dart';

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
  double explanationThreshold = 50000,
}) {
  final normalized = rawActualCash.trim();
  if (normalized.isEmpty || !RegExp(r'\d').hasMatch(normalized)) {
    return const ClosingCashAssessment(
      actualCash: null,
      difference: null,
      needsExplanation: false,
    );
  }
  final parsed = parseCurrency(normalized, fallback: -1);
  final actualCash = parsed >= 0 ? parsed : null;
  final difference = actualCash == null ? null : actualCash - expectedCash;

  return ClosingCashAssessment(
    actualCash: actualCash,
    difference: difference,
    needsExplanation:
        difference != null && difference.abs() > explanationThreshold,
  );
}
