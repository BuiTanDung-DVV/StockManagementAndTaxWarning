import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/dashboard/providers/dashboard_action_provider.dart';

Map<String, dynamic> actionJson({
  required String key,
  required String severity,
  int score = 1,
}) => {
  'actionKey': key,
  'severity': severity,
  'priorityScore': score,
  'title': key,
  'detail': 'Chi tiết $key',
  'badge': severity,
};

void main() {
  test('parses a complete action center response without local fallback', () {
    final data = DashboardActionData.fromJson({
      'asOf': '2026-08-24T08:00:00.000Z',
      'items': [
        actionJson(key: 'RECEIVABLE_OVERDUE', severity: 'CRITICAL'),
        actionJson(key: 'INVENTORY_LOW_STOCK', severity: 'WARNING'),
      ],
      'healthySummary': [
        actionJson(key: 'TAX_HEALTHY', severity: 'HEALTHY', score: 0),
      ],
    });

    expect(data.items.first.severity, DashboardActionSeverity.critical);
    expect(
      data.healthySummary.single.severity,
      DashboardActionSeverity.healthy,
    );
  });

  test('rejects healthy records mixed into actionable items', () {
    expect(
      () => DashboardActionData.fromJson({
        'asOf': '2026-08-24T08:00:00.000Z',
        'items': [actionJson(key: 'INVENTORY_HEALTHY', severity: 'HEALTHY')],
        'healthySummary': const [],
      }),
      throwsFormatException,
    );
  });

  test('maps action keys to screens with the relevant filter', () {
    expect(
      DashboardActionItem.fromJson(
        actionJson(key: 'RECEIVABLE_OVERDUE', severity: 'CRITICAL'),
      ).destination,
      '/customer-debts?status=overdue',
    );
    expect(
      DashboardActionItem.fromJson(
        actionJson(key: 'INVENTORY_LOW_STOCK', severity: 'WARNING'),
      ).destination,
      '/inventory?issue=low-stock',
    );
  });
}
