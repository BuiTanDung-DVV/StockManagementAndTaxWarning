import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/theme/theme_provider.dart';
import 'package:flutter_app/core/widgets/ai_assistant_widget.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/dashboard/providers/dashboard_action_provider.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/settings/presentation/ai_knowledge_management_screen.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/shell/main_shell.dart';
import '../support/load_ui_fonts.dart';

class _MockAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isLoggedIn: true,
    user: {
      'fullName': 'Nguyễn Văn Quản Lý',
      'email': 'admin@smartstock.vn',
      'role': 'OWNER',
    },
  );
}

class _MockShop extends ShopNotifier {
  @override
  ShopState build() => const ShopState(
    currentShopId: 1,
    currentShopName: 'VLXD & Điện Nước Minh Sang',
    memberType: 'OWNER',
    status: 'ACTIVE',
    isLoading: false,
    userShops: [
      {'id': 1, 'name': 'VLXD & Điện Nước Minh Sang'},
    ],
  );
}

class _MockApiClient extends ApiClient {
  _MockApiClient() : super();

  @override
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path == '/ai/chat') {
      final question = (data is Map ? data['question']?.toString() : '') ?? '';
      if (question.contains('Tóm tắt') || question.contains('tồn kho')) {
        return {
          'success': true,
          'data': {
            'answer':
                '**TỔNG HỢP TÌNH HÌNH KINH DOANH & KHO HÀNG**\n\n'
                '• **Kho hàng:** Đang quản lý 85 mặt hàng, tổng tồn kho 12.450 đơn vị, tổng giá trị vốn ước tính **1.450.000.000 VNĐ**.\n'
                '• **Mặt hàng HẾT SẠCH (Tồn = 0):** Thép cuộn Phi 6, Xi măng Hà Tiên PCB40, Ổ cắm âm tường Sino -> *Cần nhập khẩn cấp!*\n'
                '• **Chạm định mức an toàn:** Thép cây D10 (còn 20 cây / mức 100), Gạch xây ống (còn 300 viên / mức 1.500).\n'
                '• **Hiệu quả 30 ngày:** Doanh thu đạt **3.125.000.000 VNĐ** (428 đơn hàng). Top bán chạy: Ống nhựa Tiền Phong, Sơn Dulux, Xi măng.\n'
                '• **Tài chính & Nợ:** Nợ khách hàng cần thu: **185.000.000 VNĐ**, Nợ nhà cung cấp phải trả: **240.000.000 VNĐ**.\n\n'
                '*Khuyến nghị:* Cửa hàng đang có dòng tiền bán hàng tốt, nên liên hệ ngay Nhà cung cấp để nhập bù 3 mặt hàng đã về 0 nhằm tránh đứt gãy nguồn cung cho khách hàng.',
            'provider': 'SmartStock Business Advisor',
          },
        };
      } else {
        return {
          'success': true,
          'data': {
            'answer':
                '**CĂN CỨ VỀ NGHĨA VỤ THUẾ HỘ KINH DOANH**\n\n'
                'Theo quy định tại **Thông tư 40/2021/TT-BTC** và **Luật Quản lý thuế số 38/2019/QH14**:\n\n'
                '1. **Ngưỡng doanh thu chịu thuế:**\n'
                '   - Hộ kinh doanh, cá nhân kinh doanh có doanh thu trong năm dương lịch từ **100 triệu đồng trở xuống** thuộc diện **không phải nộp thuế GTGT và thuế TNCN**.\n'
                '   - Doanh thu trên 100 triệu đồng/năm bắt buộc phải kê khai và nộp thuế theo tỷ lệ ngành nghề kinh doanh.\n\n'
                '2. **Tỷ lệ tính thuế đối với ngành phân phối, cung cấp hàng hóa:**\n'
                '   - Thuế GTGT: **1%** trên doanh thu tính thuế.\n'
                '   - Thuế TNCN: **0,5%** trên doanh thu tính thuế.\n\n'
                '[Nguồn 1] [Nguồn 2] Cửa hàng mình đang có doanh thu 3,1 tỷ/tháng, thuộc diện bắt buộc kê khai thuế định kỳ đầy đủ.',
            'provider': 'Google Gemini 2.5 Flash',
            'sources': [
              {
                'title':
                    'Thông tư 40/2021/TT-BTC hướng dẫn thuế GTGT, TNCN HKD',
                'url':
                    'https://vbpl.vn/botaichinh/Pages/vbpq-van-ban-goc.aspx?ItemID=148560',
              },
              {
                'title':
                    'Luật Quản lý thuế số 38/2019/QH14 - Cổng TTĐT Chính Phủ',
                'url':
                    'https://vanban.chinhphu.vn/default.aspx?pageid=27160&docid=197318',
              },
            ],
            'claims': [
              {
                'text':
                    'Hộ kinh doanh doanh thu từ 100 triệu đồng/năm trở xuống không phải nộp thuế GTGT và TNCN.',
                'sourceUrls': [
                  'https://vbpl.vn/botaichinh/Pages/vbpq-van-ban-goc.aspx?ItemID=148560',
                ],
              },
            ],
            'searchedAt': '2026-09-24T07:15:00Z',
          },
        };
      }
    } else if (path == '/ai/knowledge/extract-url') {
      return {
        'success': true,
        'data': {
          'title': 'Chính sách chiết khấu & Thưởng đại lý vật liệu năm 2026',
          'content':
              'Điều 1: Áp dụng chiết khấu 3.5% cho đơn hàng thanh toán ngay bằng chuyển khoản.\n'
              'Điều 2: Hạn mức công nợ tối đa không quá 30 ngày hoặc 500 triệu đồng.\n'
              'Điều 3: Thưởng quý 1% nếu đạt sản lượng thép trên 50 tấn.',
        },
      };
    }
    return {'success': true};
  }
}

void main() {
  setUpAll(loadUiFonts);
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> capture(WidgetTester tester, Key key, String fileName) async {
    final boundaryFinder = find.byKey(key);
    final boundary =
        tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
    final image = await tester.runAsync(
      () => boundary.toImage(pixelRatio: 1.0),
    );
    final byteData = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    final file = File(
      'BA_DOCUMENTS/TEST_RUNS/ai_assistant_screenshots/$fileName',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(byteData!.buffer.asUint8List());
  }

  Widget createTestApp({required Widget child, bool openAi = false}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(() => _MockAuth()),
        shopProvider.overrideWith(() => _MockShop()),
        apiClientProvider.overrideWithValue(_MockApiClient()),
        salesSummaryProvider.overrideWith(
          (ref, period) async => {
            'orderCount': 428,
            'totalOrders': 428,
            'netSalesRevenue': 3125000000,
            'grossProfit': 625000000,
            'totalCogs': 2500000000,
            'returnNetSalesRevenue': 0,
            'returnRatePct': 0,
            'timezone': 'Asia/Ho_Chi_Minh',
            'period': {'from': period.from, 'to': period.to},
            'daily': [
              {
                'date': period.from,
                'revenue': 3125000000,
                'cogs': 2500000000,
                'grossProfit': 625000000,
                'marginPct': 20.0,
                'orderCount': 428,
              },
            ],
          },
        ),
        cashSummaryProvider.overrideWith(
          (ref, period) async => {
            'income': 3200000000,
            'expense': 2100000000,
            'netCashFlow': 1100000000,
            'cashBalance': 1850000000,
            'period': {'name': 'custom', 'from': period.from, 'to': period.to},
            'dailyFlow': [
              {
                'date': period.from,
                'income': 3200000000,
                'expense': 2100000000,
              },
            ],
          },
        ),
        inventoryCategoriesSummaryProvider.overrideWith(
          (ref) async => [
            {
              'category': 'Vật liệu xây dựng',
              'productCount': 45,
              'totalStock': 8500,
              'stockValue': 980000000,
              'unit': 'Tấn/Bao',
              'growthStatus': 'HIGH',
            },
            {
              'category': 'Thiết bị điện dân dụng',
              'productCount': 40,
              'totalStock': 3950,
              'stockValue': 470000000,
              'unit': 'Cái/Cuộn',
              'growthStatus': 'NORMAL',
            },
          ],
        ),
        dashboardActionProvider.overrideWith(
          (_) async => DashboardActionData(
            asOf: DateTime(2026, 9, 24),
            items: const [],
            healthySummary: const [],
          ),
        ),
        taxObligationsProvider.overrideWith((ref) async => {'items': []}),
        if (openAi)
          aiAssistantOpenProvider.overrideWith(
            () => _AlwaysOpenAiNotifier(true),
          ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(AppBrandColor.luminaBlue.color),
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [GoRoute(path: '/', builder: (_, _) => child)],
        ),
      ),
    );
  }

  group('AI Assistant Visual Inspection & Button Click Verification', () {
    testWidgets('01 - Mascot noi (Floating Mascot) tren Dashboard', (
      tester,
    ) async {
      const key = ValueKey('ai_mascot_capture');
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: createTestApp(
            child: const MainShell(child: DashboardScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra sự xuất hiện của nút Mascot AI trên Header Shell
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message?.contains('Trợ lý AI') == true,
        ),
        findsOneWidget,
      );

      await capture(tester, key, '01_ai_launcher_mascot.png');
    });

    testWidgets(
      '02 - Mo Panel AI mac dinh (Compact 408px) & nut Quick Questions',
      (tester) async {
        const key = ValueKey('ai_panel_compact_capture');
        await tester.binding.setSurfaceSize(const Size(1280, 800));

        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: createTestApp(
              openAi: true,
              child: const MainShell(child: DashboardScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Xác thực các nút & thành phần trên Panel
        expect(find.text('Trợ giúp nghiệp vụ'), findsOneWidget);
        expect(find.text('Tóm tắt tình hình cửa hàng'), findsOneWidget);
        expect(find.text('Sản phẩm nào cần xử lý tồn kho?'), findsOneWidget);
        expect(find.text('Công nợ nào cần ưu tiên?'), findsOneWidget);
        expect(find.text('Gửi'), findsOneWidget);
        expect(find.byTooltip('Làm mới'), findsOneWidget);
        expect(find.text('Mở rộng'), findsWidgets);

        await capture(tester, key, '02_ai_panel_compact.png');
      },
    );

    testWidgets('03 - Nhan nut Mo rong -> Panel phong to 720px', (
      tester,
    ) async {
      const key = ValueKey('ai_panel_expanded_capture');
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: createTestApp(
            openAi: true,
            child: const MainShell(child: DashboardScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Click nút Mở rộng trên header của panel AI (phần tử thứ 2)
      final expandBtns = find.text('Mở rộng');
      expect(expandBtns, findsWidgets);
      await tester.tap(expandBtns.last);
      await tester.pumpAndSettle();

      // Panel đã mở rộng và nút đổi thành "Thu gọn"
      expect(find.text('Thu gọn'), findsWidgets);

      await capture(tester, key, '03_ai_panel_expanded.png');
    });

    testWidgets(
      '04 - Nhan Quick Question -> Tro ly phan hoi chi tiet kho hang & doanh thu',
      (tester) async {
        const key = ValueKey('ai_panel_response_capture');
        await tester.binding.setSurfaceSize(const Size(1280, 800));

        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: createTestApp(
              openAi: true,
              child: const MainShell(child: DashboardScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Bấm câu hỏi nhanh "Tóm tắt tình hình cửa hàng"
        final quickBtn = find.text('Tóm tắt tình hình cửa hàng');
        await tester.tap(quickBtn);
        await tester.pump(); // Start loading
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Xác nhận AI trả về đầy đủ số liệu tồn kho, giá trị vốn, mặt hàng hết hàng
        expect(
          find.textContaining('TỔNG HỢP TÌNH HÌNH KINH DOANH'),
          findsOneWidget,
        );
        expect(find.textContaining('1.450.000.000 VNĐ'), findsOneWidget);
        expect(find.textContaining('Thép cuộn Phi 6'), findsOneWidget);
        expect(find.text('Sao chép'), findsWidgets);

        await capture(tester, key, '04_ai_panel_store_summary.png');

        // Test tiếp nút Sao chép
        await tester.tap(find.text('Sao chép').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await capture(tester, key, '05_ai_copy_snack.png');
      },
    );

    testWidgets(
      '05 - Tra cuu Phap luat/Thue -> Hien thi Can cu & Nguon dan chung',
      (tester) async {
        const key = ValueKey('ai_legal_capture');
        await tester.binding.setSurfaceSize(const Size(1280, 800));

        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: createTestApp(
              openAi: true,
              child: const MainShell(child: DashboardScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nhập câu hỏi vào ô tìm kiếm
        final textField = find.byType(TextField);
        await tester.enterText(
          textField,
          'Doanh thu bao nhiêu thì hộ kinh doanh phải nộp thuế?',
        );
        await tester.tap(find.text('Gửi'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Kiểm tra phản hồi có grounding và nguồn
        expect(find.textContaining('Thông tư 40/2021/TT-BTC'), findsWidgets);
        expect(find.textContaining('Nguồn đã kiểm tra'), findsOneWidget);

        await capture(tester, key, '06_ai_legal_grounding.png');

        // Test nút Làm mới (Reset Chat)
        final resetBtn = find.byTooltip('Làm mới');
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        // Sau khi reset, quay lại tin nhắn chào ban đầu và các câu hỏi thường dùng
        expect(find.text('Tóm tắt tình hình cửa hàng'), findsOneWidget);
        await capture(tester, key, '07_ai_reset_chat.png');
      },
    );

    testWidgets(
      '06 - Man hinh Nguon tai lieu tri thuc & Modal Them tai lieu da dinh dang',
      (tester) async {
        const key = ValueKey('ai_knowledge_capture');
        await tester.binding.setSurfaceSize(const Size(1000, 750));

        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: createTestApp(child: const AiKnowledgeManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nguồn tài liệu tham khảo'), findsOneWidget);
        await capture(tester, key, '08_ai_knowledge_screen.png');

        // Mở modal Thêm tài liệu mới
        final addBtn = find.byIcon(Icons.add_rounded);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // Kiểm tra có các nút Tải tệp PDF, Word, TXT và Dán đường link URL
        expect(find.text('Tải tệp (PDF, Word, TXT)'), findsOneWidget);
        expect(find.text('Dán đường link (URL)'), findsOneWidget);
        expect(find.text('Lưu nguồn'), findsOneWidget);

        // Nhấp nút Dán đường link (URL) để mở ô nhập link
        await tester.tap(find.text('Dán đường link (URL)'));
        await tester.pumpAndSettle();
        expect(find.text('Trích xuất'), findsOneWidget);

        await capture(tester, key, '09_ai_add_document_modal.png');
      },
    );
  });
}

class _AlwaysOpenAiNotifier extends AiAssistantOpenNotifier {
  final bool _open;
  _AlwaysOpenAiNotifier(this._open);
  @override
  bool build() => _open;
}
