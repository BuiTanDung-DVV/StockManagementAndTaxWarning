import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/type_parser.dart';
import '../providers/product_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);



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
    final theme = Theme.of(context);
    final searchQuery = ref.watch(_productSearchQueryProvider);
    final listAsync = ref.watch(productListProvider((page: 1, search: searchQuery.isEmpty ? null : searchQuery)));
    
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Danh mục sản phẩm',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          featureGuideButton(context, 'product_list'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/products/form'),
        icon: const Icon(Icons.add_box_rounded),
        label: Text('Thêm sản phẩm', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Styled Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), 
            child: TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                filled: true,
                fillColor: c.card,
                hintText: 'Tìm sản phẩm theo tên, SKU...', 
                prefixIcon: Icon(Icons.search_rounded, color: c.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: c.divider.withValues(alpha: 0.6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: listAsync.when(
              data: (data) {
                final items = (data['items'] as List?) ?? [];
                if (items.isEmpty) {
                  return const AppEmpty(
                    message: 'Chưa có sản phẩm', 
                    subtitle: 'Hãy thêm sản phẩm đầu tiên hoặc thử từ khóa tìm kiếm khác'
                  );
                }
                return RefreshIndicator(
                  color: theme.colorScheme.primary,
                  onRefresh: () async => ref.invalidate(productListProvider),
                  child: GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    itemCount: items.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 450,
                      mainAxisExtent: 110, // Expanded slightly to fit custom details beautifully
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (_, i) {
                      final p = items[i];
                      final price = TypeParser.asDouble(p['sellingPrice'] ?? p['sellPrice'] ?? p['retailPrice']);
                      final stock = p['currentStock'] ?? p['stock'] ?? 0;
                      final imageUrl = p['imageUrl']?.toString() ?? '';
                      final isOutOfStock = stock <= 0;

                      return Container(
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isOutOfStock 
                                ? AppColors.danger.withValues(alpha: 0.2)
                                : c.divider.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              final rawId = p['id'];
                              final id = rawId is int ? rawId : int.tryParse('${rawId ?? ''}');
                              if (id != null) {
                                context.push('/products/$id');
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Product Image Frame with sophisticated outline
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: c.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: c.divider.withValues(alpha: 0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Stack(
                                        children: [
                                          if (imageUrl.isNotEmpty)
                                            CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              width: 70,
                                              height: 70,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(color: c.surface),
                                              errorWidget: (context, url, error) => _buildImageFallback(theme),
                                            )
                                          else
                                            _buildImageFallback(theme),
                                          
                                          // Out of stock glassy red tag overlay
                                          if (isOutOfStock)
                                            Container(
                                              color: AppColors.danger.withValues(alpha: 0.35),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'HẾT HÀNG',
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  
                                  // Info layout
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start, 
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          p['name'] ?? '', 
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 14,
                                            color: c.textPrimary
                                          ), 
                                          maxLines: 1, 
                                          overflow: TextOverflow.ellipsis
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'SKU: ${p['sku'] ?? 'N/A'}', 
                                          style: TextStyle(
                                            fontSize: 11, 
                                            color: c.textSecondary,
                                            fontWeight: FontWeight.w500
                                          ), 
                                          maxLines: 1, 
                                          overflow: TextOverflow.ellipsis
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isOutOfStock 
                                                ? AppColors.danger.withValues(alpha: 0.08)
                                                : (stock < 10 
                                                    ? AppColors.warning.withValues(alpha: 0.08)
                                                    : AppColors.success.withValues(alpha: 0.08)),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: isOutOfStock 
                                                      ? AppColors.danger
                                                      : (stock < 10 ? AppColors.warning : AppColors.success),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                isOutOfStock ? 'Hết hàng' : 'Còn tồn: $stock', 
                                                style: TextStyle(
                                                  fontSize: 10.5, 
                                                  fontWeight: FontWeight.bold,
                                                  color: isOutOfStock 
                                                      ? AppColors.danger
                                                      : (stock < 10 ? AppColors.warning : AppColors.success),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  
                                  // Price tag Outfit bold
                                  Text(
                                    _currFmt.format(price), 
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w800, 
                                      fontSize: 14,
                                      color: theme.colorScheme.primary,
                                    )
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  ),
                );
              },
              loading: () => const ShimmerList(),
              error: (e, _) => AppError(
                message: 'Lỗi tải dữ liệu: $e', 
                onRetry: () => ref.invalidate(productListProvider)
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFallback(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined, 
        color: theme.colorScheme.primary.withValues(alpha: 0.6),
        size: 24,
      ),
    );
  }
}
