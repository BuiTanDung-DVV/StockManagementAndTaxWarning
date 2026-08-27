import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:flutter_app/features/dashboard/providers/dashboard_action_provider.dart';

DashboardActionItem action(
  String key,
  DashboardActionSeverity severity, {
  String? title,
}) => DashboardActionItem(
  actionKey: key,
  severity: severity,
  priorityScore: 100,
  title: title ?? key,
  detail: 'Chi tiết $key',
  badge: switch (severity) {
    DashboardActionSeverity.critical => 'Khẩn cấp',
    DashboardActionSeverity.warning => 'Cần xử lý',
    DashboardActionSeverity.info => 'Theo dõi',
    DashboardActionSeverity.healthy => 'Đang ổn định',
  },
);

Widget appWith(
  DashboardActionData data, {
  double width = 360,
  double height = 440,
  bool fixedHeight = true,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: width,
                height: fixedHeight ? height : null,
                child: DashboardPriorityList(fixedHeight: fixedHeight),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/customer-debts',
        builder: (_, state) => Text(
          'Đích ${state.uri.queryParameters['status']}',
          textDirection: TextDirection.ltr,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [dashboardActionProvider.overrideWith((_) async => data)],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme(AppColors.primary),
      routerConfig: router,
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows explicit healthy state when there are zero actions', (
    tester,
  ) async {
    final data = DashboardActionData(
      asOf: DateTime(2026, 8, 24),
      items: const [],
      healthySummary: [
        action(
          'INVENTORY_HEALTHY',
          DashboardActionSeverity.healthy,
          title: 'Tồn kho trong định mức',
        ),
      ],
    );
    await tester.pumpWidget(appWith(data));
    await tester.pumpAndSettle();

    expect(find.text('Không có việc cần xử lý ngay'), findsOneWidget);
    expect(find.textContaining('Tồn kho trong định mức'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps six actions scrollable and critical item first', (
    tester,
  ) async {
    final data = DashboardActionData(
      asOf: DateTime(2026, 8, 24),
      items: [
        action(
          'RECEIVABLE_OVERDUE',
          DashboardActionSeverity.critical,
          title: 'Nợ quá hạn',
        ),
        for (var index = 0; index < 5; index++)
          action(
            'INVENTORY_LOW_STOCK_$index',
            DashboardActionSeverity.warning,
            title: 'Cảnh báo kho $index',
          ),
      ],
      healthySummary: const [],
    );
    await tester.pumpWidget(appWith(data));
    await tester.pumpAndSettle();

    expect(find.text('Nợ quá hạn'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.getSize(find.byType(DashboardPriorityList)).height, 440);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile renders three actions in the page scroll only', (
    tester,
  ) async {
    final data = DashboardActionData(
      asOf: DateTime(2026, 8, 24),
      items: [
        action('CRITICAL', DashboardActionSeverity.critical),
        action('WARNING', DashboardActionSeverity.warning),
        action('INFO', DashboardActionSeverity.info),
      ],
      healthySummary: const [],
    );
    await tester.pumpWidget(
      appWith(data, width: 390, height: 800, fixedHeight: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('CRITICAL'), findsOneWidget);
    expect(find.text('WARNING'), findsOneWidget);
    expect(find.text('INFO'), findsOneWidget);
    expect(find.byType(Scrollable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('click opens the destination with its filter', (tester) async {
    final data = DashboardActionData(
      asOf: DateTime(2026, 8, 24),
      items: [
        action(
          'RECEIVABLE_OVERDUE',
          DashboardActionSeverity.critical,
          title: 'Nợ quá hạn',
        ),
      ],
      healthySummary: const [],
    );
    await tester.pumpWidget(appWith(data));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nợ quá hạn'));
    await tester.pumpAndSettle();

    expect(find.text('Đích overdue'), findsOneWidget);
  });
}
