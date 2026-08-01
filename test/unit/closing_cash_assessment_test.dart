import 'package:flutter_app/features/finance/domain/closing_cash_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('assessClosingCash', () {
    test('keeps an empty input unassessed instead of treating it as zero', () {
      final result = assessClosingCash(
        rawActualCash: '',
        expectedCash: 1919881000,
      );

      expect(result.actualCash, isNull);
      expect(result.difference, isNull);
      expect(result.canSubmit, isFalse);
      expect(result.needsExplanation, isFalse);
    });

    test('accepts a real zero and calculates the difference', () {
      final result = assessClosingCash(
        rawActualCash: '0',
        expectedCash: 100000,
      );

      expect(result.actualCash, 0);
      expect(result.difference, -100000);
      expect(result.canSubmit, isTrue);
      expect(result.needsExplanation, isTrue);
    });

    test('rejects invalid and negative values', () {
      expect(
        assessClosingCash(rawActualCash: 'abc', expectedCash: 0).canSubmit,
        isFalse,
      );
      expect(
        assessClosingCash(rawActualCash: '-1', expectedCash: 0).canSubmit,
        isFalse,
      );
    });
  });
}
