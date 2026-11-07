import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/settings/providers/shop_provider.dart';
import '../../features/finance/providers/finance_provider.dart';
import '../../features/sales/providers/sales_provider.dart';
import '../../features/inventory/providers/inventory_provider.dart';
import '../../features/products/providers/product_provider.dart';
import '../../features/customers/providers/customer_provider.dart';
import '../network/api_client.dart';
import 'offline_store.dart';
import 'offline_sync_engine.dart';
import 'offline_store_provider.dart';
export 'offline_store_provider.dart';
import 'offline_submission.dart';
import 'offline_read_cache.dart';
import 'offline_catalog.dart';
import 'offline_session.dart';

final offlineCatalogProvider = FutureProvider<OfflineCatalog>(
  (ref) async => OfflineCatalog(
    store: await ref.watch(offlineStoreProvider.future),
    currentScope: () => ref.read(offlineScopeProvider),
  ),
);

Future<Map<String, Object?>> prepareOfflineCatalog(
  WidgetRef ref, {
  void Function(String resource, int loaded, int total)? onProgress,
}) async {
  final scope = ref.read(offlineScopeProvider);
  if (scope == null || ref.read(authProvider).isOfflineSession) {
    throw ApiException(
      'Cần đăng nhập trực tuyến và chọn cửa hàng trước khi tải.',
    );
  }
  final prepared = await OfflineSessionStore(
    await ref.read(offlineStoreProvider.future),
  ).read();
  if (prepared == null || prepared.scope.key != scope.key) {
    throw ApiException(
      'Chuẩn bị quyền mở cục bộ trên thiết bị trước khi tải danh mục.',
    );
  }
  bool canRead(String key) =>
      prepared.shop['memberType'] == 'OWNER' ||
      const [
        'view',
        'edit',
        'full',
      ].contains((prepared.shop['permissions'] as Map? ?? {})[key]);
  final resources = <String>{
    if (canRead('products')) ...[
      'products',
      'categories',
      'tags:product',
      'tags:customer',
      'tags:supplier',
    ],
    if (canRead('customers')) 'customers',
    if (canRead('suppliers')) 'suppliers',
    if (canRead('inventory')) 'inventory/warehouses',
  };
  bool current() =>
      ref.context.mounted &&
      ref.read(offlineScopeProvider)?.key == scope.key &&
      !ref.read(authProvider).isOfflineSession;
  final catalog = await ref.read(offlineCatalogProvider.future);
  return catalog.prepare(
    scope: scope,
    resources: resources,
    isCurrent: current,
    loadOnline: (path, params) => ref
        .read(apiClientProvider)
        .getOnlineInShop(
          path,
          '${scope.shopId}',
          params: params,
          isCurrentScope: current,
        ),
    onProgress: onProgress,
  );
}

final offlineScopeProvider = Provider<OfflineScope?>((ref) {
  final auth = ref.watch(authProvider);
  final shop = ref.watch(shopProvider);
  final userId = int.tryParse(auth.user?['id']?.toString() ?? '');
  if (!auth.isLoggedIn ||
      userId == null ||
      shop.currentShopId == null ||
      shop.isAllShops ||
      !shop.isActive) {
    return null;
  }
  return OfflineScope(userId: userId, shopId: shop.currentShopId!);
});

final offlineReadCacheProvider = FutureProvider<OfflineReadCache>((ref) async {
  final cache = OfflineReadCache(
    store: await ref.watch(offlineStoreProvider.future),
    currentScope: () => ref.read(offlineScopeProvider),
    catalog: await ref.watch(offlineCatalogProvider.future),
  );
  final api = ref.read(apiClientProvider);
  api.readCache = cache;
  ref.listen(offlineScopeProvider, (_, _) => cache.scopeChanged());
  ref.onDispose(() {
    if (identical(api.readCache, cache)) api.readCache = null;
    unawaited(cache.close());
  });
  return cache;
});

final offlineReadStatusProvider = StreamProvider<OfflineReadStatus>((
  ref,
) async* {
  final cache = await ref.watch(offlineReadCacheProvider.future);
  yield cache.status;
  yield* cache.changes;
});

final offlineSyncEngineProvider = FutureProvider<OfflineSyncEngine>((
  ref,
) async {
  final store = await ref.watch(offlineStoreProvider.future);
  bool current(OfflineScope scope) =>
      ref.read(offlineScopeProvider)?.key == scope.key;
  return OfflineSyncEngine(
    store: store,
    isCurrentScope: current,
    onConfirmed: (operation) {
      ref.invalidate(transactionsProvider);
      ref.invalidate(cashSummaryProvider);
      ref.invalidate(profitLossProvider);
      ref.invalidate(expensesByCategoryProvider);
      ref.invalidate(expensesByCategoryForPeriodProvider);
      ref.invalidate(dailyClosingProvider);
      ref.invalidate(cashflowProjectionProvider);
      ref.invalidate(budgetPlansProvider);
      if (operation.kind == 'SALES_ORDER_CREATE') {
        ref.invalidate(salesListProvider);
        ref.invalidate(salesSummaryProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(stockProvider);
        ref.invalidate(stockPageProvider);
        ref.invalidate(inventoryMovementsProvider);
        ref.invalidate(inventoryCategoriesSummaryProvider);
        ref.invalidate(lowStockProvider);
        ref.invalidate(customerListProvider);
        ref.invalidate(taxObligationsProvider);
        ref.invalidate(cashAccountsProvider);
      }
      if (operation.kind == 'PURCHASE_ORDER_CREATE') {
        ref.invalidate(purchaseOrdersProvider);
      }
    },
    transport: (scope, envelope) async {
      try {
        if (ref.read(authProvider).isOfflineSession) {
          await ref.read(authProvider.notifier).reconnectOfflineSession();
        }
        if (!current(scope) || ref.read(authProvider).isOfflineSession) {
          throw const SyncTransportFailure(
            'Chưa xác thực lại được phiên làm việc. Ghi chép vẫn được giữ trên thiết bị.',
          );
        }
        final result = await ref.read(apiClientProvider).postInShop(
          '/sync/operations',
          scope.shopId.toString(),
          {'actorId': scope.userId, ...envelope},
          isCurrentScope: () => current(scope),
        );
        if (result is! Map) {
          throw const SyncTransportFailure('Phản hồi đồng bộ không hợp lệ.');
        }
        return Map<String, dynamic>.from(result);
      } on ApiException catch (error) {
        throw SyncTransportFailure(
          error.message,
          error.statusCode,
          error.details,
        );
      }
    },
  );
});

final offlineSubmissionProvider = FutureProvider<OfflineSubmission>((
  ref,
) async {
  return OfflineSubmission(
    store: await ref.watch(offlineStoreProvider.future),
    engine: await ref.watch(offlineSyncEngineProvider.future),
    isCurrentScope: (scope) => ref.read(offlineScopeProvider)?.key == scope.key,
  );
});

Future<OfflineSubmissionResult> saveCashFromForm(
  WidgetRef ref,
  Map<String, dynamic> payload,
  OfflineFormIdentity identity,
) async {
  final scope = ref.read(offlineScopeProvider);
  if (scope == null) {
    throw ApiException(
      'Chọn một cửa hàng và chờ tải tài khoản trước khi ghi thu/chi.',
    );
  }
  final submission = await ref.read(offlineSubmissionProvider.future);
  final saved = await submission.save(
    scope,
    'CASH_TRANSACTION_CREATE',
    payload,
    operationId: identity.forPayload(payload),
  );
  if (ref.read(offlineScopeProvider)?.key != scope.key) {
    throw ApiException(
      'Tài khoản hoặc cửa hàng đã thay đổi. Ghi chép được giữ trong cửa hàng ban đầu.',
    );
  }
  if (saved.operation.status == 'rejected' ||
      saved.operation.status == 'authRequired') {
    throw ApiException(
      saved.operation.message ?? 'Ghi chép đã được giữ lại để kiểm tra.',
    );
  }
  return saved;
}

/// Runs only while the app is open, and only after explicit auto-sync opt-in.
/// A device/browser must not silently upload another account/shop's outbox.
final offlineBackgroundSyncProvider = Provider<void>((ref) {
  var disposed = false;
  Future<void> tick() async {
    final scope = ref.read(offlineScopeProvider);
    if (scope == null) return;
    try {
      final engine = await ref.read(offlineSyncEngineProvider.future);
      if (!disposed) await engine.sync(scope);
    } catch (_) {
      // Storage/transport errors leave drafts intact. The workspace shows them.
    }
  }

  final timer = Timer.periodic(
    const Duration(seconds: 20),
    (_) => unawaited(tick()),
  );
  ref.listen(offlineScopeProvider, (_, _) => unawaited(tick()));
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
  });
  unawaited(Future.microtask(tick));
});
