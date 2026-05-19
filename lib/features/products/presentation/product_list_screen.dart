import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/product_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final _productSearchQueryProvider = NotifierProvider<_SearchQueryNotifier, String>(_SearchQueryNotifier.new);

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(_productSearchQueryProvider.notifier).set(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final searchQuery = ref.watch(_productSearchQueryProvider);
    final listAsync = ref.watch(productListProvider((page: 1, search: searchQuery.isEmpty ? null : searchQuery)));
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Sản phẩm'),
        actions: [
          featureGuideButton(context, 'product_list'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/products/form'),
        icon: const Icon(Icons.inventory_2),
        label: const Text('Thêm'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16), 
          child: TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm...', 
              prefixIcon: Icon(Icons.search, color: c.textMuted)
            )
          )
        ),
        Expanded(child: listAsync.when(
          data: (data) {
            final items = (data['items'] as List?) ?? [];
            if (items.isEmpty) return const AppEmpty(message: 'Chưa có sản phẩm', subtitle: 'Hãy thêm sản phẩm đầu tiên hoặc thử tìm kiếm khác');
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(productListProvider),
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 450,
                  mainAxisExtent: 100, // Increased to prevent overflow
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (_, i) {
                final p = items[i];
                final price = _asDouble(p['sellingPrice'] ?? p['sellPrice'] ?? p['retailPrice']);
                final stock = p['currentStock'] ?? p['stock'] ?? 0;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final rawId = p['id'];
                    final id = rawId is int ? rawId : int.tryParse('${rawId ?? ''}');
                    if (id != null) {
                      context.push('/products/$id');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Container(width: 55, height: 55, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.inventory_2, color: AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('SKU: ${p['sku'] ?? 'N/A'}', style: TextStyle(fontSize: 11, color: c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('Tồn: $stock', style: TextStyle(fontSize: 11, color: stock < 10 ? AppColors.danger : c.textSecondary)),
                      ])),
                      Text(_currFmt.format(price), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ]),
                  ),
                );
              }),
            );
          },
          loading: () => const ShimmerList(),
          error: (e, _) => AppError(message: 'Lỗi: $e', onRetry: () => ref.invalidate(productListProvider)),
        )),
      ]),
    );
  }
}

