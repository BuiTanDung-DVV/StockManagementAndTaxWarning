import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:flutter_app/features/dashboard/providers/dashboard_action_provider.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';

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

  group('TaxObligationReminder status, timezone and edge-case handling', () {
    DateTime fixedClock() =>
        DateTime.utc(2026, 9, 15, 2, 0); // 2026-09-15 09:00 in VN

    testWidgets('excludes done, paid, and cancelled statuses', (tester) async {
      final items = [
        {
          'id': 1,
          'period': 'Q1/2026',
          'status': 'done',
          'dueDate': '2026-04-30',
        },
        {
          'id': 2,
          'period': 'Q2/2026',
          'status': 'paid',
          'dueDate': '2026-07-30',
        },
        {
          'id': 3,
          'period': 'Q3/2026',
          'status': 'cancelled',
          'dueDate': '2026-10-30',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taxObligationsProvider.overrideWith(
              (ref) => Future.value({'items': items}),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(body: TaxObligationReminder(clock: fixedClock)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsNothing);
      expect(find.textContaining('Thuế Q1'), findsNothing);
      expect(find.textContaining('Thuế Q2'), findsNothing);
      expect(find.textContaining('Thuế Q3'), findsNothing);
    });

    testWidgets(
      'status=overdue with future dueDate displays "Cần đối chiếu trạng thái"',
      (tester) async {
        final items = [
          {
            'id': 10,
            'period': 'T9/2026',
            'status': 'overdue',
            'dueDate': '2026-09-30', // future relative to 2026-09-15
            'vatDeclared': 5000000,
            'vatPaid': 0,
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taxObligationsProvider.overrideWith(
                (ref) => Future.value({'items': items}),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: Scaffold(body: TaxObligationReminder(clock: fixedClock)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cần đối chiếu trạng thái'), findsOneWidget);
        expect(find.textContaining('Quá hạn -'), findsNothing);
        expect(find.text('Thuế T9/2026'), findsOneWidget);
      },
    );

    testWidgets(
      'handles true overdue, due today, and null dueDate cleanly with top 3 limit',
      (tester) async {
        final items = [
          {
            'id': 11,
            'period': 'T7/2026',
            'status': 'pending',
            'dueDate': '2026-09-10', // 5 days past relative to 2026-09-15
            'vatDeclared': 2000000,
            'vatPaid': 0,
          },
          {
            'id': 12,
            'period': 'T8/2026',
            'status': 'pending',
            'dueDate': '2026-09-15', // today relative to 2026-09-15
            'vatDeclared': 3000000,
            'vatPaid': 0,
          },
          {
            'id': 13,
            'period': 'T6/2026',
            'status': 'pending',
            'dueDate': null, // null dueDate
            'vatDeclared': 1000000,
            'vatPaid': 0,
          },
          for (var i = 14; i <= 16; i++)
            {
              'id': i,
              'period': 'T$i/2026',
              'status': 'pending',
              'dueDate': '2026-11-$i',
              'vatDeclared': 1000000,
              'vatPaid': 0,
            },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taxObligationsProvider.overrideWith(
                (ref) => Future.value({'items': items}),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: Scaffold(body: TaxObligationReminder(clock: fixedClock)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // True overdue
        expect(find.text('Quá hạn 5 ngày'), findsOneWidget);
        // Due today
        expect(find.text('Đến hạn hôm nay'), findsOneWidget);
        // Null dueDate explicitly says "Chưa xác định hạn"
        expect(find.text('Chưa xác định hạn'), findsOneWidget);
        expect(find.text('Hạn: Chưa xác định'), findsOneWidget);
        // Top 5 limit: 6th item (T16) is excluded
        expect(find.text('Thuế T16/2026'), findsNothing);
        // See all link is visible after limiting 5
        expect(find.text('Xem tất cả'), findsOneWidget);
      },
    );

    testWidgets(
      'rejects normalized invalid dates like 2026-02-31 and malformed prefixes as null',
      (tester) async {
        final items = [
          {
            'id': 20,
            'period': 'T2/2026',
            'status': 'pending',
            'dueDate':
                '2026-02-31', // invalid date that Dart would normalize to March 3rd
            'vatDeclared': 1000000,
            'vatPaid': 0,
          },
          {
            'id': 21,
            'period': 'T3/2026',
            'status': 'pending',
            'dueDate': '2026-03-15malformed_prefix',
            'vatDeclared': 1000000,
            'vatPaid': 0,
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taxObligationsProvider.overrideWith(
                (ref) => Future.value({'items': items}),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: Scaffold(body: TaxObligationReminder(clock: fixedClock)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Both invalid dates are rejected and displayed as "Chưa xác định hạn"
        expect(find.text('Chưa xác định hạn'), findsNWidgets(2));
        expect(find.text('Hạn: Chưa xác định'), findsNWidgets(2));
        expect(find.textContaining('2026-03-03'), findsNothing);
      },
    );

    testWidgets(
      'timestamp without zone parses as contract date-only without machine TZ dependency',
      (tester) async {
        final items = [
          {
            'id': 25,
            'period': 'T9/2026',
            'status': 'pending',
            'dueDate': '2026-09-15T00:00:00', // timestamp without zone
            'vatDeclared': 5000000,
            'vatPaid': 0,
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taxObligationsProvider.overrideWith(
                (ref) => Future.value({'items': items}),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: Scaffold(body: TaxObligationReminder(clock: fixedClock)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 2026-09-15 relative to fixedClock (2026-09-15) is due today
        expect(find.text('Đến hạn hôm nay'), findsOneWidget);
        expect(find.text('Hạn: 2026-09-15'), findsOneWidget);
        expect(find.textContaining('Còn phải nộp: 5.000.000'), findsOneWidget);
      },
    );

    testWidgets(
      'Long status Row renders cleanly at 390px with textScaler 150% without overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final items = [
          {
            'id': 30,
            'period': 'Quý 4/2026 (Kỳ dài)',
            'status': 'overdue',
            'dueDate':
                '2026-10-31', // future relative to 2026-09-15 -> 'Cần đối chiếu trạng thái'
            'vatDeclared': 123456789,
            'vatPaid': 0,
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taxObligationsProvider.overrideWith(
                (ref) => Future.value({'items': items}),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(390, 844),
                  textScaler: TextScaler.linear(1.5),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: TaxObligationReminder(clock: fixedClock),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cần đối chiếu trạng thái'), findsOneWidget);
        expect(find.textContaining('Thuế Quý 4/2026'), findsOneWidget);
        expect(
          find.textContaining('Còn phải nộp: 123.456.789'),
          findsOneWidget,
        );
        expect(find.text('Hạn: 2026-10-31'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
