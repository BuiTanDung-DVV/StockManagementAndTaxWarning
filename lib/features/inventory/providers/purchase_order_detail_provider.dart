import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/shop_provider.dart';
import 'inventory_provider.dart';
import '../../../core/providers/data_freshness_provider.dart';

typedef PurchaseOrderDetailKey = ({int id, int shopId, int userId});

final purchaseOrderDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, PurchaseOrderDetailKey>((ref, key) async {
      watchDataFreshness(ref, DataArea.inventory);
      ref.watch(shopProvider);
      ref.watch(authProvider);
      var alive = true;
      ref.onDispose(() => alive = false);
      bool current() {
        if (!alive) return false;
        final shop = ref.read(shopProvider);
        final auth = ref.read(authProvider);
        return auth.isLoggedIn &&
            !auth.isOfflineSession &&
            '${auth.user?['id']}' == '${key.userId}' &&
            !shop.isAllShops &&
            shop.currentShopId == key.shopId &&
            shop.hasPermission('inventory');
      }

      if (!current()) {
        throw ApiException('Phạm vi xem đơn nhập đã thay đổi.', 403);
      }
      final result = await ref
          .watch(inventoryRepoProvider)
          .getPurchaseOrderInShop(key.id, key.shopId, isCurrentScope: current);
      if (!current()) {
        throw ApiException('Phạm vi xem đơn nhập đã thay đổi.', 403);
      }
      return result;
    });
