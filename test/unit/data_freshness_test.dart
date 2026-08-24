import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/utils/data_freshness.dart';

void main() {
  test('cảnh báo khi kỳ hiện tại chưa có bản ghi mới từ DB', () {
    final result = assessDataFreshness(
      latestDate: '2026-07-28',
      periodFrom: DateTime(2026, 8, 1),
      periodTo: DateTime(2026, 8, 20),
      recordCount: 0,
    );

    expect(result.state, DataFreshnessState.missingPeriod);
    expect(result.daysBehind, 23);
  });

  test('cảnh báo kỳ chưa đủ ngày dù đã có một phần dữ liệu', () {
    final result = assessDataFreshness(
      latestDate: '2026-08-15',
      periodFrom: DateTime(2026, 8, 1),
      periodTo: DateTime(2026, 8, 20),
      recordCount: 12,
    );

    expect(result.state, DataFreshnessState.incompletePeriod);
    expect(result.daysBehind, 5);
  });

  test('không cảnh báo khi DB có dữ liệu đến cuối kỳ', () {
    final result = assessDataFreshness(
      latestDate: '2026-08-20',
      periodFrom: DateTime(2026, 8, 1),
      periodTo: DateTime(2026, 8, 20),
      recordCount: 20,
    );

    expect(result.state, DataFreshnessState.current);
    expect(result.requiresAttention, isFalse);
  });
}
