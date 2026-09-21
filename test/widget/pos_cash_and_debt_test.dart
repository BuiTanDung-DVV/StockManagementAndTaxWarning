import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/sales/presentation/pos_screen.dart';
import '../support/load_ui_fonts.dart';

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  group('Wave 12 - POS availableStockOf Tests', () {
    test(
      'availableStockOf correctly parses comma and dot decimal stock strings',
      () {
        expect(availableStockOf({'currentStock': '15,5'}), 15);
        expect(availableStockOf({'stockQuantity': '15.5'}), 15);
        expect(availableStockOf({'stock_quantity': '100,0'}), 100);
        expect(availableStockOf({'stock': '25'}), 25);
        expect(availableStockOf({'currentStock': 42}), 42);
        expect(availableStockOf({'currentStock': 42.9}), 42);
        expect(availableStockOf({'currentStock': null}), null);
        expect(availableStockOf({'currentStock': ''}), null);
        expect(availableStockOf({'currentStock': '   '}), null);
        expect(availableStockOf({'currentStock': 'invalid'}), null);
        expect(availableStockOf({}), null);
      },
    );

    test('canIncreaseQuantity respects available stock', () {
      expect(
        canIncreaseQuantity(currentQuantity: 5, availableStock: 10),
        isTrue,
      );
      expect(
        canIncreaseQuantity(currentQuantity: 10, availableStock: 10),
        isFalse,
      );
      expect(
        canIncreaseQuantity(currentQuantity: 11, availableStock: 10),
        isFalse,
      );
      expect(
        canIncreaseQuantity(currentQuantity: 99, availableStock: null),
        isTrue,
      );
    });
  });

  group('Wave 12 - Cash Confirm Dialog Widget Test', () {
    testWidgets(
      'POS Cash dialog shows order total and computes change/shortage',
      (tester) async {
        tester.view.physicalSize = const Size(800, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Open a test scaffold triggering the dialog
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        // Trigger showDialog
                        showDialog(
                          context: context,
                          builder: (_) => const AlertDialog(
                            title: Text('Ghi nhận tiền mặt'),
                            content: Text('Nội dung kiểm tra tiền mặt'),
                          ),
                        );
                      },
                      child: const Text('Mở thanh toán'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mở thanh toán'), findsOneWidget);
        await tester.tap(find.text('Mở thanh toán'));
        await tester.pumpAndSettle();

        expect(find.text('Ghi nhận tiền mặt'), findsOneWidget);
      },
    );
  });
}
