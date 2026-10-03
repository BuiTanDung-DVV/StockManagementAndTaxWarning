import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/settings/presentation/ai_knowledge_management_screen.dart';
import 'package:flutter_app/features/settings/providers/ai_knowledge_provider.dart';
import '../support/load_ui_fonts.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20261001_compliance/screenshots';

Future<void> _capture(WidgetTester tester, Key key, String fileName) async {
  final boundaryFinder = find.byKey(key);
  final boundary =
      tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  final byteData = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final path = '$_runDir/$fileName';
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData!.buffer.asUint8List());
}

class _MockKnowledgeNotifier extends AiKnowledgeNotifier {
  final List<AiDocument> _mockDocs;
  _MockKnowledgeNotifier(this._mockDocs);

  @override
  Future<List<AiDocument>> build() async => _mockDocs;

  @override
  Future<void> addDocument({
    required String title,
    required String category,
    required String content,
  }) async {
    // mock no-op
  }
}

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  final List<AiDocument> sampleDocs = [
    AiDocument(
      id: 'doc-1',
      title: 'Thông tư 88/2021/TT-BTC - Chế độ kế toán cho Hộ kinh doanh',
      category: 'Thuế HKD',
      content:
          'Quy định 7 mẫu sổ kế toán áp dụng cho hộ kinh doanh, cá nhân kinh doanh nộp thuế theo phương pháp kê khai.',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AiDocument(
      id: 'doc-2',
      title: 'Quy trình kiểm soát hạn mức công nợ khách lẻ',
      category: 'Bán Hàng & Sổ Nợ',
      content:
          'Hạn mức tín dụng tối đa 10.000.000 VNĐ. Khóa tài khoản nợ nếu quá hạn 30 ngày.',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  testWidgets('Visual inspection & RAG knowledge modal verification', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiKnowledgeProvider.overrideWith(
            () => _MockKnowledgeNotifier(sampleDocs),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          builder: (context, child) {
            return RepaintBoundary(
              key: repaintKey,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const Scaffold(body: AiKnowledgeManagementScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify list items and RAG ground badge
    expect(find.text('RAG Grounding'), findsOneWidget);
    expect(
      find.text('Thông tư 88/2021/TT-BTC - Chế độ kế toán cho Hộ kinh doanh'),
      findsOneWidget,
    );
    expect(
      find.text('Quy trình kiểm soát hạn mức công nợ khách lẻ'),
      findsOneWidget,
    );

    // Capture main screen
    await _capture(tester, repaintKey, 'ai_knowledge_list_screen.png');

    // Tap "Nạp tài liệu mới" button to open BottomSheet
    final addDocBtn = find.text('Nạp tài liệu mới');
    expect(addDocBtn, findsOneWidget);
    await tester.tap(addDocBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Bottom Sheet elements
    expect(find.text('Thêm nguồn tham khảo'), findsOneWidget);
    expect(find.text('Tải tệp (PDF, Word, TXT, JSON)'), findsOneWidget);
    expect(find.text('Dán đường link (URL)'), findsOneWidget);
    expect(find.text('Mẫu quy định & chính sách chuẩn (1-Chạm)'), findsOneWidget);

    // Tap to show URL input & suggestions
    await tester.tap(find.text('Dán đường link (URL)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('thuedientu.gdt.gov.vn'), findsOneWidget);

    // Open ExpansionTile for Legal Presets
    await tester.tap(find.text('Mẫu quy định & chính sách chuẩn (1-Chạm)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Tap "Áp dụng" on Thông tư 40 preset
    final applyBtns = find.text('Áp dụng');
    expect(applyBtns, findsWidgets);
    await tester.tap(applyBtns.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify that title and content were populated with Thông tư 40 (present in both list item and text field)
    expect(
      find.text('Thông tư 40/2021/TT-BTC - Hướng dẫn thuế Hộ kinh doanh'),
      findsNWidgets(2),
    );

    // Capture the modal state with preset applied
    await _capture(tester, repaintKey, 'ai_knowledge_add_preset_applied.png');
  });
}
