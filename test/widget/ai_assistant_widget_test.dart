import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/ai_assistant_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHost() {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme(AppColors.primary),
      home: const Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: Size(390, 700)),
          child: SizedBox(
            width: 390,
            height: 700,
            child: AiAssistantWidget(topSafeInset: 56),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('floating AI launcher opens the assistant panel', (tester) async {
    await tester.pumpWidget(_buildHost());
    await tester.pumpAndSettle();

    final launcher = find.bySemanticsLabel('Hỏi AI. Có thể kéo để đổi vị trí.');
    expect(launcher, findsOneWidget);

    await tester.tap(launcher);
    await tester.pumpAndSettle();

    expect(find.text('Trợ giúp nghiệp vụ'), findsOneWidget);
    expect(launcher, findsOneWidget);
  });

  testWidgets('dragging the AI launcher persists its normalized position', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHost());
    await tester.pumpAndSettle();

    final launcher = find.bySemanticsLabel('Hỏi AI. Có thể kéo để đổi vị trí.');
    final initialPosition = tester.getTopLeft(launcher);

    await tester.drag(launcher, const Offset(120, -160));
    await tester.pumpAndSettle();

    final movedPosition = tester.getTopLeft(launcher);
    expect(movedPosition.dx, greaterThan(initialPosition.dx));
    expect(movedPosition.dy, lessThan(initialPosition.dy));

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble('ai_assistant_launcher_x_v2'), isNotNull);
    expect(preferences.getDouble('ai_assistant_launcher_y_v2'), isNotNull);
  });

  testWidgets('AI launcher can be hidden with its close control', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHost());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ẩn nút AI'), findsOneWidget);
    await tester.tap(find.byTooltip('Ẩn nút AI'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ẩn nút AI'), findsNothing);
  });
}
