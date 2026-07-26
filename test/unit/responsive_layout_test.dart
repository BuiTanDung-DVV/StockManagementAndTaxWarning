import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/widgets/responsive_layout.dart';

void main() {
  testWidgets('AppFillGrid fills one compact column without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: AppFillGrid(
                minItemWidth: 200,
                children: [
                  SizedBox(key: Key('first'), height: 40),
                  SizedBox(key: Key('second'), height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('first'))).width, 320);
    expect(tester.getTopLeft(find.byKey(const Key('second'))).dy, 56);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppFillGrid recalculates columns from parent width', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 700,
              child: AppFillGrid(
                minItemWidth: 200,
                maxColumns: 3,
                children: [
                  SizedBox(key: Key('first'), height: 40),
                  SizedBox(key: Key('second'), height: 40),
                  SizedBox(key: Key('third'), height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final itemWidth = tester.getSize(find.byKey(const Key('first'))).width;
    expect(itemWidth, closeTo((700 - 32) / 3, 0.01));
    expect(
      tester.getTopLeft(find.byKey(const Key('third'))).dx,
      greaterThan(400),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AppResponsiveContent caps wide content and keeps adaptive inset',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1200,
                child: AppResponsiveContent(
                  maxWidth: 1000,
                  child: SizedBox(key: Key('content'), height: 40),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const Key('content'))).width, 936);
      expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, 132);
      expect(tester.takeException(), isNull);
    },
  );
}
