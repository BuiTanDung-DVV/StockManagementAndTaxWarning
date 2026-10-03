import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/guides/feature_guide_sheet.dart';
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/app_confirm_modal.dart';
import 'package:flutter_app/core/widgets/custom_date_range_picker.dart';
import 'package:flutter_app/core/widgets/global_search_delegate.dart';
import 'package:flutter_app/core/widgets/reporting_period_control.dart';
import 'package:flutter_app/features/auth/presentation/widgets/join_shop_dialog.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/finance/presentation/invoice_editor_dialog.dart';
import 'package:flutter_app/features/finance/presentation/purchase_no_invoice_screen.dart';
import 'package:flutter_app/features/finance/presentation/tax_obligation_screen.dart';
import 'package:flutter_app/features/sales/presentation/pos_screen.dart';
import 'package:flutter_app/features/settings/presentation/avatar_picker_dialog.dart';
import 'package:flutter_app/features/settings/presentation/shop_payment_qr_dialog.dart';
import 'package:flutter_app/features/settings/presentation/theme_appearance_modal.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/tax/widgets/tax_export_format_dialog.dart';
import '../support/load_ui_fonts.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20261001_popups/screenshots';

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

class _FakeShopNotifier extends ShopNotifier {
  final ShopState _initial;
  _FakeShopNotifier(this._initial);

  @override
  ShopState build() => _initial;

  @override
  Future<void> loadUserShops() async {}
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;

  @override
  Future<List<Map<String, dynamic>>> searchShops(String query) async {
    return [
      {
        'id': 'shop_101',
        'name': 'Cửa hàng Thực phẩm Bến Thành',
        'code': 'SHOP-BT-01',
        'ownerName': 'Trần Văn Nam',
        'address': 'Quận 1, TP. Hồ Chí Minh',
      },
      {
        'id': 'shop_102',
        'name': 'Siêu thị Mini Long An',
        'code': 'SHOP-LA-02',
        'ownerName': 'Lê Thị Hoa',
        'address': 'Bến Lức, Long An',
      },
    ];
  }
}

class _FakeApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    if (path.contains('shop-payment-qr')) {
      return {
        'imageUrl': 'https://example.com/qr.png',
        'displayText': 'Ngân hàng Quân Đội MB - 0901234567',
        'details': {
          'bankName': 'MB Bank',
          'accountNo': '0901234567',
          'accountName': 'BUI TAN DUNG',
        },
      };
    }
    if (path.contains('search')) {
      return [
        {
          'id': 1,
          'type': 'PRODUCT',
          'title': 'Sữa tươi Tiệt trùng Vinamilk 1L',
          'subtitle': 'SKU: VNM-MILK-1L • Tồn kho: 24 hộp',
          'price': 34000.0,
        },
        {
          'id': 2,
          'type': 'CUSTOMER',
          'title': 'Nguyễn Văn Minh (Khách quen)',
          'subtitle': 'SĐT: 0987654321 • Nợ: 120.000 ₫',
        },
      ];
    }
    return {};
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async => {'success': true};
  @override
  Future<dynamic> put(String path, {dynamic data}) async => {'success': true};
}

Widget _dialogHost({
  required Key key,
  required void Function(BuildContext context, WidgetRef ref) onOpen,
  Size size = const Size(1440, 900),
  List overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: SizedBox(
      width: size.width,
      height: size.height,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(AppColors.primary),
        builder: (context, child) {
          return RepaintBoundary(
            key: key,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9), // Slate 100 base
          body: Center(
            child: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  key: const ValueKey('open_dialog_btn'),
                  onPressed: () => onOpen(context, ref),
                  child: const Text('Mở Hộp Thoại'),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadUiFonts();
    SharedPreferences.setMockInitialValues({});
  });

  const fakeShopState = ShopState(
    currentShopId: 1,
    currentShopName: 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
    memberType: 'OWNER',
    status: 'ACTIVE',
  );

  const fakeAuthState = AuthState(
    isLoggedIn: true,
    token: 'fake_jwt_token',
    user: {
      'id': 1,
      'fullName': 'Bùi Tấn Dũng',
      'email': 'tandung@smartstock.vn',
      'role': 'OWNER',
    },
  );

  group('All Popups, Modals & Dialogs Visual Audit', () {
    testWidgets('01_pos_cash_confirm_dialog', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('pos_cash_confirm_rep_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => CashConfirmDialog(
                total: 350000,
                onConfirm: () {},
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Ghi nhận tiền mặt'), findsOneWidget);
      await _capture(tester, key, '01_pos_cash_confirm_dialog.png');
    });

    testWidgets('02_join_shop_dialog', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('join_shop_dialog_rep_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
          ],
          onOpen: (context, _) {
            showDialog(
              context: context,
              builder: (_) => const JoinShopDialog(),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Gia nhập cửa hàng'), findsWidgets);
      await _capture(tester, key, '02_join_shop_dialog.png');
    });

    testWidgets('03_app_confirm_modal_destructive', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('app_confirm_modal_destructive_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            AppConfirmModal.show(
              context,
              title: 'Xóa vĩnh viễn sản phẩm?',
              message:
                  'Hành động này không thể hoàn tác. Mọi lịch sử tồn kho liên quan cũng sẽ bị gỡ bỏ.',
              confirmText: 'Xác nhận xóa',
              cancelText: 'Giữ lại',
              isDestructive: true,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Xóa vĩnh viễn sản phẩm?'), findsOneWidget);
      await _capture(tester, key, '03_app_confirm_modal_destructive.png');
    });

    testWidgets('04_app_confirm_modal_normal', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('app_confirm_modal_normal_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            AppConfirmModal.show(
              context,
              title: 'Xác nhận kết ca & khóa sổ',
              message:
                  'Tổng tiền mặt kiểm đếm thực tế khớp 100% với sổ sách. Bạn có muốn khóa sổ ca làm việc hôm nay không?',
              confirmText: 'Khóa sổ ca',
              cancelText: 'Kiểm tra lại',
              isDestructive: false,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận kết ca & khóa sổ'), findsOneWidget);
      await _capture(tester, key, '04_app_confirm_modal_normal.png');
    });

    testWidgets('05_invoice_editor_dialog', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('invoice_editor_dialog_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => InvoiceEditorDialog(
                onSubmit: (_) async {},
                initialInvoice: {
                  'invoiceNumber': 'HD-2026-0089',
                  'partnerName': 'Công ty CP Phân phối Thực phẩm An Phát',
                  'invoiceType': 'IN',
                  'items': [
                    {
                      'name': 'Gạo Nàng Thơm Chợ Đào',
                      'qty': 20,
                      'unit': 'Bao 10kg',
                      'unitPrice': 220000,
                      'vatRate': 5,
                    },
                    {
                      'name': 'Dầu ăn Tường An 5L',
                      'qty': 10,
                      'unit': 'Can',
                      'unitPrice': 185000,
                      'vatRate': 8,
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Chỉnh sửa hóa đơn'), findsOneWidget);
      await _capture(tester, key, '05_invoice_editor_dialog.png');
    });

    testWidgets('06_tax_export_format_dialog', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('tax_export_format_dialog_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            showTaxExportFormatDialog(
              context: context,
              period: '9',
              year: '2026',
              formCode: '01/CNKD',
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Chọn định dạng xuất tờ khai'), findsOneWidget);
      await _capture(tester, key, '06_tax_export_format_dialog.png');
    });

    testWidgets('07_shop_payment_qr_dialog', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('shop_payment_qr_dialog_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          overrides: [
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          onOpen: (context, _) {
            showShopPaymentQrDialog(context, canManage: true);
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('QR của cửa hàng'), findsOneWidget);
      await _capture(tester, key, '07_shop_payment_qr_dialog.png');
    });

    testWidgets('08_theme_appearance_modal', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('theme_appearance_modal_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            ThemeAppearanceModal.show(context);
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(ThemeAppearanceModal), findsOneWidget);
      await _capture(tester, key, '08_theme_appearance_modal.png');
    });

    testWidgets('09_avatar_picker_dialog', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('avatar_picker_dialog_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            AvatarPickerDialog.show(context);
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(AvatarPickerDialog), findsOneWidget);
      await _capture(tester, key, '09_avatar_picker_dialog.png');
    });

    testWidgets('10_add_purchase_no_invoice_dialog', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('add_purchase_no_invoice_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AddPurchaseNoInvoiceDialog(
                formatCurrency: (v) => '$v ₫',
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(AddPurchaseNoInvoiceDialog), findsOneWidget);
      await _capture(tester, key, '10_add_purchase_no_invoice_dialog.png');
    });

    testWidgets('11_add_tax_obligation_dialog', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('add_tax_obligation_dialog_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, ref) {
            showDialog(
              context: context,
              builder: (_) => AddTaxObligationDialog(ref: ref),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(AddTaxObligationDialog), findsOneWidget);
      await _capture(tester, key, '11_add_tax_obligation_dialog.png');
    });

    testWidgets('12_edit_tax_obligation_dialog', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('edit_tax_obligation_dialog_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, ref) {
            showDialog(
              context: context,
              builder: (_) => EditTaxObligationDialog(
                ref: ref,
                item: {
                  'id': 10,
                  'taxPeriod': 'Q3/2026',
                  'vatAmount': 1500000.0,
                  'pitAmount': 750000.0,
                  'vatPaid': 1000000.0,
                  'pitPaid': 500000.0,
                  'status': 'partial',
                },
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(EditTaxObligationDialog), findsOneWidget);
      await _capture(tester, key, '12_edit_tax_obligation_dialog.png');
    });

    testWidgets('13_feature_guide_sheet', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('feature_guide_sheet_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            showFeatureGuide(context, 'pos');
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hướng dẫn:'), findsOneWidget);
      await _capture(tester, key, '13_feature_guide_sheet.png');
    });

    testWidgets('14_reporting_period_dialog', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('reporting_period_dialog_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            showReportingPeriodEditor(
              context,
              today: DateTime(2026, 10, 1),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Phạm vi số liệu'), findsWidgets);
      await _capture(tester, key, '14_reporting_period_dialog.png');
    });

    testWidgets('15_global_search_dialog', (tester) async {
      const size = Size(1440, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('global_search_dialog_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            showGlobalSearchPanel(context, api: _FakeApiClient());
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tìm kiếm'), findsWidgets);
      await _capture(tester, key, '15_global_search_dialog.png');
    });

    testWidgets('16_custom_date_range_picker_mobile', (tester) async {
      const size = Size(390, 844);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('custom_date_range_picker_key');
      await tester.pumpWidget(
        _dialogHost(
          key: key,
          size: size,
          onOpen: (context, _) {
            showCustomDateRangePicker(
              context,
              initialRange: DateTimeRange(
                start: DateTime(2026, 9, 1),
                end: DateTime(2026, 9, 30),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Chọn thời gian'), findsWidgets);
      await _capture(tester, key, '16_custom_date_range_picker.png');
    });
  });
}
