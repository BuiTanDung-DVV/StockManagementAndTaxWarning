import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('web content can be dragged with a mouse pointer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: ListView.builder(
            itemCount: 30,
            itemBuilder: (_, index) =>
                SizedBox(height: 80, child: Text('Dòng $index')),
          ),
        ),
      ),
    );

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, 0);

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 1,
    );
    await gesture.addPointer(location: const Offset(200, 400));
    await gesture.down(const Offset(200, 400));
    await gesture.moveBy(const Offset(0, -240));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(0));
  });
}
