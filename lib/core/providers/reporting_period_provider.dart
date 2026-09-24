import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/reporting_period.dart';

/// Trạng thái lưu trữ kỳ báo cáo riêng biệt cho từng Tab / Phân hệ chức năng
class TabPeriodState {
  final Map<String, ReportingPeriodSelection> periods;

  const TabPeriodState({required this.periods});

  ReportingPeriodSelection getForTab(String tabKey) {
    return periods[tabKey] ??
        ReportingPeriodSelection(
          periodType: ReportingPeriodType.month,
          anchorDate: DateTime.now(),
          comparisonType: ReportingComparisonType.previousPeriod,
        );
  }

  TabPeriodState copyWithTab(
    String tabKey,
    ReportingPeriodSelection selection,
  ) {
    return TabPeriodState(periods: {...periods, tabKey: selection});
  }
}

class ReportingPeriodNotifier extends Notifier<TabPeriodState> {
  @override
  TabPeriodState build() {
    final now = DateTime.now();
    final defaultSelection = ReportingPeriodSelection(
      periodType: ReportingPeriodType.month,
      anchorDate: now,
      comparisonType: ReportingComparisonType.previousPeriod,
    );
    return TabPeriodState(
      periods: {
        'dashboard': defaultSelection,
        'sales': defaultSelection,
        'inventory': defaultSelection,
        'finance': defaultSelection,
      },
    );
  }

  void setPeriodForTab(String tabKey, ReportingPeriodSelection selection) {
    state = state.copyWithTab(tabKey, selection);
  }
}

/// Provider quản lý cấu hình kỳ báo cáo lưu nhớ cho từng trang/tab
final reportingPeriodNotifierProvider =
    NotifierProvider<ReportingPeriodNotifier, TabPeriodState>(
      ReportingPeriodNotifier.new,
    );

/// Trích xuất mã tab chính từ đường dẫn URL
String resolveTabKeyFromLocation(String path) {
  if (path.startsWith('/sales') ||
      path.startsWith('/orders') ||
      path.startsWith('/customers') ||
      path.startsWith('/pos')) {
    return 'sales';
  }
  if (path.startsWith('/inventory') ||
      path.startsWith('/products') ||
      path.startsWith('/suppliers') ||
      path.startsWith('/warehouses') ||
      path.startsWith('/purchase-orders') ||
      path.startsWith('/stock-takes')) {
    return 'inventory';
  }
  if (path.startsWith('/finance') ||
      path.startsWith('/transactions') ||
      path.startsWith('/invoices') ||
      path.startsWith('/daily-closing') ||
      path.startsWith('/expense') ||
      path.startsWith('/profit-loss') ||
      path.startsWith('/cashflow') ||
      path.startsWith('/debt') ||
      path.startsWith('/customer-debts') ||
      path.startsWith('/supplier-payables') ||
      path.startsWith('/salary') ||
      path.startsWith('/tax')) {
    return 'finance';
  }
  return 'dashboard';
}

/// Tên tiếng Việt hiển thị của tab
String resolveTabName(String tabKey) {
  switch (tabKey) {
    case 'sales':
      return 'Bán hàng';
    case 'inventory':
      return 'Kho hàng';
    case 'finance':
      return 'Tài chính';
    default:
      return 'Tổng quan';
  }
}

/// Provider cung cấp kỳ đã phân giải (ResolvedReportingPeriods) cho tab tương ứng
final tabResolvedPeriodProvider =
    Provider.family<ResolvedReportingPeriods, String>((ref, tabKey) {
      final state = ref.watch(reportingPeriodNotifierProvider);
      final selection = state.getForTab(tabKey);
      return resolveReportingPeriods(selection, today: DateTime.now());
    });

/// Provider cung cấp lựa chọn kỳ hiện tại cho tab tương ứng
final tabSelectionProvider = Provider.family<ReportingPeriodSelection, String>((
  ref,
  tabKey,
) {
  final state = ref.watch(reportingPeriodNotifierProvider);
  return state.getForTab(tabKey);
});
