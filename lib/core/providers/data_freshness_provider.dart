import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Read dependencies affected by a committed mutation in the current session.
/// These counters do not replace account/shop state or hold business data.
enum DataArea {
  products,
  tags,
  inventory,
  sales,
  customers,
  suppliers,
  finance,
  system,
  audit,
  scans,
  dashboard,
  documents,
  taxConfig,
  access,
  identity,
  notifications,
}

Set<DataArea> mutationDataAreas(String method, String path) {
  if (!{'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method.toUpperCase()))
    return {};
  final parts = Uri.parse(
    path,
  ).path.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.isNotEmpty && parts.first == 'api') parts.removeAt(0);
  final route = parts.join('/');
  if (parts.isEmpty) return {};
  final root = parts.first;

  // POST is also used for read-only previews, exports and staged uploads.
  if (RegExp(r'/(inspect|preview|snapshot|validate|export)$').hasMatch(route) ||
      RegExp(
        r'/(image-upload|evidence-upload)(/(delete|confirm))?$',
      ).hasMatch(route) ||
      route == 'shop-payment-qr/upload' ||
      route == 'shop-profile/receipt-logo/upload' ||
      root == 'auth' ||
      root == 'ai' ||
      root == 'sync' ||
      route.endsWith('/request') ||
      route == 'profile/password')
    return {};

  Set<DataArea> areas;
  switch (root) {
    case 'products':
    case 'categories':
    case 'cost-types':
      areas = {
        DataArea.products,
        DataArea.inventory,
        DataArea.sales,
        DataArea.dashboard,
      };
    case 'tags':
      areas = {
        DataArea.tags,
        DataArea.products,
        DataArea.customers,
        DataArea.suppliers,
        DataArea.inventory,
      };
    case 'sales-orders':
    case 'sales-returns':
      areas = {
        DataArea.sales,
        DataArea.inventory,
        DataArea.products,
        DataArea.customers,
        DataArea.finance,
        DataArea.dashboard,
      };
    case 'inventory':
    case 'purchase-orders':
    case 'stock-takes':
    case 'cogs':
      areas = {
        DataArea.inventory,
        DataArea.products,
        DataArea.suppliers,
        DataArea.finance,
        DataArea.dashboard,
      };
    case 'customers':
    case 'receivables':
      areas = {
        DataArea.customers,
        DataArea.sales,
        DataArea.finance,
        DataArea.dashboard,
      };
    case 'suppliers':
    case 'payables':
      areas = {
        DataArea.suppliers,
        DataArea.inventory,
        DataArea.finance,
        DataArea.dashboard,
      };
    case 'cash-transactions':
      areas = {
        DataArea.finance,
        DataArea.customers,
        DataArea.suppliers,
        DataArea.sales,
        DataArea.dashboard,
      };
    case 'cashflow-forecasts':
    case 'budget-plans':
    case 'daily-closings':
    case 'invoices':
    case 'tax-obligations':
      areas = {DataArea.finance, DataArea.dashboard};
    case 'purchases-without-invoice':
      areas = {
        DataArea.finance,
        DataArea.inventory,
        DataArea.products,
        DataArea.suppliers,
        DataArea.dashboard,
      };
    case 'invoice-scans':
      areas = {DataArea.scans, DataArea.finance, DataArea.dashboard};
    case 'opening-balances':
      if (route != 'opening-balances/commit') return {};
      areas = {
        DataArea.inventory,
        DataArea.products,
        DataArea.customers,
        DataArea.suppliers,
        DataArea.sales,
        DataArea.finance,
        DataArea.dashboard,
      };
    case 'shop-backups':
      if (!route.endsWith('/restore') && !route.endsWith('/rollback'))
        return {};
      areas = DataArea.values.toSet();
    case 'shipping-carriers':
      areas = {DataArea.system, DataArea.sales};
    case 'shop-profile':
    case 'configs':
    case 'shop-payment-qr':
      areas = {
        DataArea.system,
        DataArea.inventory,
        DataArea.finance,
        DataArea.taxConfig,
        DataArea.access,
      };
    case 'tax':
      if (!route.startsWith('tax/config')) return {};
      areas = {DataArea.taxConfig, DataArea.finance, DataArea.dashboard};
    case 'ai-knowledge':
      areas = {DataArea.documents};
    case 'shop-members':
    case 'shop-roles':
    case 'shops':
      areas = {DataArea.access, DataArea.notifications, DataArea.dashboard};
    case 'profile':
      areas = {DataArea.identity};
    case 'notifications':
      return {DataArea.notifications};
    default:
      return {};
  }
  return {...areas, DataArea.audit};
}

class DataFreshnessNotifier extends Notifier<Map<DataArea, int>> {
  @override
  Map<DataArea, int> build() => const {};

  void changed(Set<DataArea> areas) {
    if (areas.isEmpty) return;
    final next = {...state};
    for (final area in areas) {
      next[area] = (next[area] ?? 0) + 1;
    }
    state = Map.unmodifiable(next);
  }
}

final dataFreshnessProvider =
    NotifierProvider<DataFreshnessNotifier, Map<DataArea, int>>(
      DataFreshnessNotifier.new,
    );

/// Watching a revision refreshes loaded queries without resetting screen state.
void watchDataFreshness(Ref ref, DataArea area) {
  ref.listen(
    dataFreshnessProvider.select((revisions) => revisions[area] ?? 0),
    (_, _) => ref.invalidateSelf(),
  );
}

void listenToDataChanges(WidgetRef ref, DataArea area, void Function() reload) {
  ref.listen(dataFreshnessProvider.select((s) => s[area] ?? 0), (_, _) {
    Future.microtask(() {
      if (ref.context.mounted) reload();
    });
  });
}
