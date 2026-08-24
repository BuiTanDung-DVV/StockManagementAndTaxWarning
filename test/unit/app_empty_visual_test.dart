import 'package:flutter/material.dart';
import 'package:flutter_app/core/assets/app_assets.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/app_animations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'AppEmpty uses a generic illustration instead of the brand logo',
    (tester) async {
      await tester.pumpWidget(
        const _TestApp(child: AppEmpty(message: 'Trống')),
      );

      final icon = tester.widget<AppAssetIcon>(find.byType(AppAssetIcon));
      expect(icon.assetPath, AppAssets.emptyGeneric);
      expect(icon.assetPath, isNot(AppAssets.appIcon));
    },
  );

  testWidgets('inventory empty state uses the inventory illustration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _TestApp(
        child: AppEmpty(
          visual: AppEmptyVisual.inventory,
          message: 'Chưa có sản phẩm',
        ),
      ),
    );

    final icon = tester.widget<AppAssetIcon>(find.byType(AppAssetIcon));
    expect(icon.assetPath, AppAssets.emptyInventory);
  });

  testWidgets('compact empty state fits a bounded chart panel', (tester) async {
    await tester.pumpWidget(
      const _TestApp(
        child: SizedBox(
          width: 400,
          height: 150,
          child: AppEmpty(
            visual: AppEmptyVisual.finance,
            message: 'Chưa có giao dịch thu–chi trong kỳ',
            subtitle: 'Biểu đồ sẽ xuất hiện khi có giao dịch thực tế.',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Chưa có giao dịch thu–chi trong kỳ'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme(AppColors.primary),
      home: Scaffold(body: child),
    );
  }
}
