import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';

class GlobalSearchDelegate extends SearchDelegate<String> {
  final ApiClient api;
  final Map<String, Future<List<_SearchResult>>> _cache = {};

  GlobalSearchDelegate({required this.api});

  @override
  String get searchFieldLabel => 'Tìm sản phẩm, đơn hàng, khách hàng...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        TextButton(onPressed: () => query = '', child: const Text('Xóa')),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return TextButton(
      onPressed: () => close(context, ''),
      child: const Text('Đóng'),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchBody(context);

  Widget _buildSearchBody(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final normalized = query.trim();
    if (normalized.length < 2) {
      return ColoredBox(
        color: colors.bg,
        child: const _SearchMessage(
          assetPath: AppAssets.search,
          title: 'Tìm kiếm dữ liệu cửa hàng',
          message: 'Nhập ít nhất 2 ký tự để tra cứu dữ liệu từ hệ thống.',
        ),
      );
    }

    final future = _cache.putIfAbsent(
      normalized.toLowerCase(),
      () => _search(normalized),
    );
    return ColoredBox(
      color: colors.bg,
      child: FutureBuilder<List<_SearchResult>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _SearchMessage(
              assetPath: AppAssets.emptyGeneric,
              title: 'Không thể tìm kiếm',
              message: 'Kết nối dữ liệu đang gặp lỗi. Vui lòng thử lại.',
            );
          }

          final results = snapshot.data ?? const [];
          if (results.isEmpty) {
            return _SearchMessage(
              assetPath: AppAssets.emptyGeneric,
              title: 'Không tìm thấy kết quả',
              message: 'Không có dữ liệu phù hợp với “$normalized”.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: results.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: colors.divider,
              indent: 68,
            ),
            itemBuilder: (context, index) {
              final result = results[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.divider),
                  ),
                  child: AppAssetIcon(
                    assetPath: result.assetPath,
                    semanticLabel: result.typeLabel,
                  ),
                ),
                title: Text(
                  result.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${result.typeLabel} · ${result.subtitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => close(context, result.route),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<_SearchResult>> _search(String keyword) async {
    final batches = await Future.wait([
      _searchEndpoint('/products', keyword),
      _searchEndpoint('/sales-orders', keyword),
      _searchEndpoint('/customers', keyword),
    ]);

    final results = <_SearchResult>[];
    for (final item in batches[0]) {
      final id = item['id'];
      if (id == null) continue;
      results.add(
        _SearchResult(
          typeLabel: 'Sản phẩm',
          title: item['name']?.toString() ?? 'Sản phẩm #$id',
          subtitle: item['sku']?.toString() ?? 'Không có mã SKU',
          route: '/products/$id',
          assetPath: AppAssets.inventory,
        ),
      );
    }
    for (final item in batches[1]) {
      final id = item['id'];
      if (id == null) continue;
      final customer = item['customer'];
      results.add(
        _SearchResult(
          typeLabel: 'Đơn hàng',
          title: item['orderCode']?.toString() ?? 'Đơn hàng #$id',
          subtitle: customer is Map
              ? customer['name']?.toString() ?? 'Khách lẻ'
              : 'Khách lẻ',
          route: '/sales/$id',
          assetPath: AppAssets.orders,
        ),
      );
    }
    for (final item in batches[2]) {
      final id = item['id'];
      if (id == null) continue;
      results.add(
        _SearchResult(
          typeLabel: 'Khách hàng',
          title: item['name']?.toString() ?? 'Khách hàng #$id',
          subtitle: item['phone']?.toString() ?? 'Không có số điện thoại',
          route: '/customers/$id',
          assetPath: AppAssets.emptyPeople,
        ),
      );
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _searchEndpoint(
    String endpoint,
    String keyword,
  ) async {
    try {
      final response = await api.get(
        endpoint,
        params: {'page': '1', 'limit': '6', 'search': keyword},
      );
      if (response is! Map || response['items'] is! List) return const [];
      return (response['items'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      // A role may not have access to every data group. Keep the groups that
      // the current account is allowed to query.
      return const [];
    }
  }
}

class _SearchResult {
  final String typeLabel;
  final String title;
  final String subtitle;
  final String route;
  final String assetPath;

  const _SearchResult({
    required this.typeLabel,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.assetPath,
  });
}

class _SearchMessage extends StatelessWidget {
  final String assetPath;
  final String title;
  final String message;

  const _SearchMessage({
    required this.assetPath,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAssetIcon(assetPath: assetPath, size: 54, semanticLabel: title),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
