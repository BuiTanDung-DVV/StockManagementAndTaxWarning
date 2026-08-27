import 'package:flutter/material.dart';
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/global_search_delegate.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient extends ApiClient {
  final bool fail;
  int calls = 0;

  _FakeApiClient({this.fail = false});

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    calls++;
    if (fail) throw ApiException('Mất kết nối');
    if (path == '/products') {
      return {
        'items': [
          {
            'id': 12,
            'name': 'Xi măng PCB40 50kg',
            'sku': 'VL-XM-001',
            'imageUrl': null,
          },
        ],
      };
    }
    return {'items': <dynamic>[]};
  }
}

Widget _testApp(_FakeApiClient api) => MaterialApp(
  theme: AppTheme.lightTheme(const Color(0xFF1769AA)),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => showGlobalSearchPanel(context, api: api),
          child: const Text('Mở tìm kiếm'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('global search waits for input then shows database results', (
    tester,
  ) async {
    final api = _FakeApiClient();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(api));
    await tester.tap(find.text('Mở tìm kiếm'));
    await tester.pumpAndSettle();
    expect(find.text('Tìm kiếm toàn hệ thống'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('global-search-field')),
      'xi măng',
    );
    await tester.pump(const Duration(milliseconds: 330));
    await tester.pumpAndSettle();

    expect(find.text('Xi măng PCB40 50kg'), findsOneWidget);
    expect(find.textContaining('1 kết quả'), findsOneWidget);
    expect(api.calls, 3);
  });

  testWidgets('global search reports connection errors instead of empty data', (
    tester,
  ) async {
    final api = _FakeApiClient(fail: true);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(api));
    await tester.tap(find.text('Mở tìm kiếm'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('global-search-field')),
      'khách hàng',
    );
    await tester.pump(const Duration(milliseconds: 330));
    await tester.pumpAndSettle();

    expect(find.text('Chưa thể tìm kiếm'), findsOneWidget);
    expect(find.text('Không tìm thấy kết quả'), findsNothing);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
