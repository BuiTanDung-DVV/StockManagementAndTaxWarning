import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/providers/reporting_period_provider.dart';
import '../../lib/core/utils/reporting_period.dart';

void main() {
  group('Shell Header & Period Sync Tests', () {
    test(
      'resolveTabKeyFromLocation maps route paths correctly to tab keys',
      () {
        expect(resolveTabKeyFromLocation('/'), 'dashboard');
        expect(resolveTabKeyFromLocation('/dashboard'), 'dashboard');
        expect(resolveTabKeyFromLocation('/sales'), 'sales');
        expect(resolveTabKeyFromLocation('/sales/new'), 'sales');
        expect(resolveTabKeyFromLocation('/customers'), 'sales');
        expect(resolveTabKeyFromLocation('/inventory'), 'inventory');
        expect(resolveTabKeyFromLocation('/products'), 'inventory');
        expect(resolveTabKeyFromLocation('/suppliers'), 'inventory');
        expect(resolveTabKeyFromLocation('/finance'), 'finance');
        expect(resolveTabKeyFromLocation('/transactions'), 'finance');
        expect(resolveTabKeyFromLocation('/invoices'), 'finance');
        expect(resolveTabKeyFromLocation('/customer-debts'), 'finance');
      },
    );

    test('resolveTabName returns proper localized tab names', () {
      expect(resolveTabName('dashboard'), 'Tổng quan');
      expect(resolveTabName('sales'), 'Bán hàng');
      expect(resolveTabName('inventory'), 'Kho hàng');
      expect(resolveTabName('finance'), 'Tài chính');
    });

    test('tabResolvedPeriodProvider reacts when period is updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialDashboard = container.read(
        tabResolvedPeriodProvider('dashboard'),
      );
      expect(initialDashboard, isNotNull);

      // Change period for sales tab to quarter
      final now = DateTime.now();
      container
          .read(reportingPeriodNotifierProvider.notifier)
          .setPeriodForTab(
            'sales',
            ReportingPeriodSelection(
              periodType: ReportingPeriodType.quarter,
              anchorDate: now,
              comparisonType: ReportingComparisonType.samePeriodLastYear,
            ),
          );

      final salesSelection = container.read(tabSelectionProvider('sales'));
      expect(salesSelection, isNotNull);
      expect(salesSelection.periodType, ReportingPeriodType.quarter);
      expect(
        salesSelection.comparisonType,
        ReportingComparisonType.samePeriodLastYear,
      );

      final salesPeriod = container.read(tabResolvedPeriodProvider('sales'));
      expect(salesPeriod, isNotNull);

      // Dashboard period remains independent
      final dashboardSelection = container.read(
        tabSelectionProvider('dashboard'),
      );
      expect(dashboardSelection.periodType, ReportingPeriodType.month);
    });
  });
}
