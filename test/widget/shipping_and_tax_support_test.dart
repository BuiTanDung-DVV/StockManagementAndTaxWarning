import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/finance/providers/tax_reference_provider.dart';
import 'package:flutter_app/features/settings/presentation/ai_knowledge_management_screen.dart';
import 'package:flutter_app/features/settings/presentation/notification_list_screen.dart';
import 'package:flutter_app/features/settings/presentation/product_category_management_screen.dart';
import 'package:flutter_app/features/settings/presentation/shipping_carrier_screen.dart';
import 'package:flutter_app/features/settings/presentation/tax_support_screen.dart';
import 'package:flutter_app/features/settings/providers/ai_knowledge_provider.dart';
import 'package:flutter_app/features/settings/providers/notification_provider.dart';
import 'package:flutter_app/features/settings/providers/operations_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import '../support/load_ui_fonts.dart';

class _FakeShopNotifier extends ShopNotifier {
  final ShopState _state;
  _FakeShopNotifier(this._state);

  @override
  ShopState build() => _state;
}

class _FakeNotificationNotifier extends NotificationNotifier {
  @override
  NotificationState build() => const NotificationState(
    unreadCount: 0,
    items: [
      {
        'id': '1',
        'title': 'Cảnh báo tồn kho',
        'message': 'Sản phẩm A sắp hết',
        'type': 'STOCK_LOW',
        'isRead': false,
        'createdAt': '2026-09-20T10:00:00Z',
      },
    ],
  );

  @override
  Future<void> loadNotifications({int page = 1}) async {}
}

class _FakeAiKnowledgeNotifier extends AsyncNotifier<List<AiDocument>>
    implements AiKnowledgeNotifier {
  @override
  Future<List<AiDocument>> build() async => [
    AiDocument(
      id: 'doc-1',
      title: 'Thông tư 40/2021/TT-BTC',
      category: 'Thuế HKD',
      content: 'Hướng dẫn thuế GTGT và TNCN cho hộ kinh doanh.',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<void> addDocument({
    required String title,
    required String category,
    required String content,
  }) async {}

  @override
  Future<void> removeDocument(String id) async {}

  @override
  Future<void> toggleDocument(String id) async {}
}

class _MockSettingsOperationsRepository
    implements SettingsOperationsRepository {
  @override
  Future<List<dynamic>> carriers() async => [
    {
      'id': 1,
      'name': 'Giao Hàng Nhanh',
      'code': 'GHN',
      'phone': '19001206',
      'defaultFee': 35000,
      'isActive': true,
    },
  ];

  @override
  Future<List<dynamic>> categories({String? search}) async => [
    {
      'id': 1,
      'name': 'Gia dụng & Tiện ích',
      'description': 'Đồ dùng thiết yếu trong nhà',
      'productCount': 24,
      'isActive': true,
    },
  ];

  @override
  Future<Map<String, dynamic>> createCarrier(Map<String, dynamic> data) async =>
      data;

  @override
  Future<Map<String, dynamic>> updateCarrier(
    int id,
    Map<String, dynamic> data,
  ) async => data;

  @override
  Future<void> deactivateCarrier(int id) async {}

  @override
  Future<Map<String, dynamic>> createCategory(
    Map<String, dynamic> data,
  ) async => data;

  @override
  Future<Map<String, dynamic>> updateCategory(
    int id,
    Map<String, dynamic> data,
  ) async => data;

  @override
  Future<void> deactivateCategory(int id, {int? replacementCategoryId}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  group('Wave 15 - Settings & Operations Comprehensive Test Suite', () {
    testWidgets(
      'ShippingCarrierScreen formats currency with vi_VN locale and renders RefreshIndicator',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mockRepo = _MockSettingsOperationsRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsOperationsRepositoryProvider.overrideWithValue(mockRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ShippingCarrierScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Kiểm tra tiêu đề và dữ liệu hiển thị đúng chuẩn tiền tệ
        expect(find.text('Đơn vị vận chuyển'), findsOneWidget);
        expect(find.text('Giao Hàng Nhanh'), findsOneWidget);
        expect(find.textContaining('GHN'), findsOneWidget);
        expect(find.textContaining('35.000'), findsOneWidget);

        // Kiểm tra RefreshIndicator có mặt trong widget tree
        expect(find.byType(RefreshIndicator), findsWidgets);
      },
    );

    testWidgets(
      'TaxSupportScreen renders support links and contains RefreshIndicator',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const fakeData = TaxReferenceData(
          forms: [
            TaxDeclarationFormReference(
              code: '01_CNKD',
              name: 'Tờ khai 01/CNKD',
              description: 'Dành cho hộ kinh doanh cá thể',
              status: 'READY',
              iconKey: 'tax',
            ),
          ],
          supportLinks: [
            TaxSupportLinkReference(
              title: 'Cổng thông tin Tổng cục Thuế',
              description: 'Trang thông tin hỗ trợ và tra cứu thuế cho HKD',
              url: 'https://www.gdt.gov.vn',
              iconKey: 'account_balance',
              colorRole: 'PRIMARY',
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              shopProvider.overrideWith(
                () => _FakeShopNotifier(
                  const ShopState(
                    currentShopId: 1,
                    memberType: 'OWNER',
                    status: 'ACTIVE',
                  ),
                ),
              ),
              taxReferenceDataProvider.overrideWith((ref) async => fakeData),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const TaxSupportScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Hỗ trợ Thuế'), findsOneWidget);
        expect(find.text('Cổng thông tin Tổng cục Thuế'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'AiKnowledgeManagementScreen renders document and contains RefreshIndicator',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              shopProvider.overrideWith(
                () => _FakeShopNotifier(
                  const ShopState(
                    currentShopId: 1,
                    memberType: 'OWNER',
                    status: 'ACTIVE',
                  ),
                ),
              ),
              aiKnowledgeProvider.overrideWith(
                () => _FakeAiKnowledgeNotifier(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const AiKnowledgeManagementScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Nguồn tài liệu tham khảo'), findsOneWidget);
        expect(find.text('Thông tư 40/2021/TT-BTC'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'ProductCategoryManagementScreen renders category list with RefreshIndicator',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mockRepo = _MockSettingsOperationsRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsOperationsRepositoryProvider.overrideWithValue(mockRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ProductCategoryManagementScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Danh mục sản phẩm'), findsOneWidget);
        expect(find.text('Gia dụng & Tiện ích'), findsOneWidget);
        expect(find.textContaining('24 sản phẩm đang dùng'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'NotificationListScreen renders notification items with RefreshIndicator',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationProvider.overrideWith(
                () => _FakeNotificationNotifier(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const NotificationListScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Thông báo'), findsOneWidget);
        expect(find.text('Cảnh báo tồn kho'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );
  });
}
