import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/type_parser.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/product_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);



class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

class _TagFilterNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final _productSearchQueryProvider = NotifierProvider<_SearchQueryNotifier, String>(_SearchQueryNotifier.new);
final _productTagFilterProvider = NotifierProvider<_TagFilterNotifier, String>(_TagFilterNotifier.new);

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
    final tagQuery = ref.watch(_productTagFilterProvider);
    final listAsync = ref.watch(productListProvider((page: 1, search: searchQuery.isEmpty ? null : searchQuery, tag: tagQuery.isEmpty ? null : tagQuery)));
    
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
          if (ref.watch(authProvider).isShopOwner)
            IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedTag01, color: Colors.white, size: 22),
              onPressed: () => context.push('/products/tags'),
              tooltip: 'Quản lý Nhãn',
            ),
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
          FilterBar(
            searchHint: 'Tìm sản phẩm theo tên, SKU...',
            onSearchChanged: _onSearchChanged,
            onFilterTap: _showFilterSheet,
          ),
          // Horizontal Tag Bar
          Consumer(
            builder: (ctx, ref, child) {
              final tagsAsync = ref.watch(availableTagsProvider);
              return tagsAsync.when(
                data: (tags) {
                  if (tags.isEmpty) return const SizedBox.shrink();
                  return SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: tags.length,
                      itemBuilder: (ctx, i) {
                        final t = tags[i];
                        final isSelected = tagQuery == t.name;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Semantics(
                            button: true,
                            label: isSelected ? 'Bỏ lọc nhãn ${t.name}' : 'Lọc theo nhãn ${t.name}',
                            selected: isSelected,
                            child: ChoiceChip(
                              label: Text(t.name, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : t.uiColor)),
                              selected: isSelected,
                              onSelected: (selected) {
                                ref.read(_productTagFilterProvider.notifier).set(selected ? t.name : '');
                              },
                              selectedColor: t.uiColor,
                              backgroundColor: t.uiColor.withValues(alpha: 0.1),
                              side: BorderSide(color: t.uiColor.withValues(alpha: 0.3)),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          const SizedBox(height: 8),
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
                      mainAxisExtent: 140, // Increased to fit tags
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
                                        if (p['description'] != null && p['description'].toString().trim().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            p['description'].toString().trim(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: c.textSecondary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        if (p['tags'] != null) ...[
                                            _buildTagsRow(p['tags'], c, theme),
                                            const SizedBox(height: 6),
                                          ],
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

  Widget _buildTagsRow(dynamic tagsRaw, AppThemeColors c, ThemeData theme) {
    List<String> tags = [];
    if (tagsRaw is List) {
      tags = tagsRaw.map((e) => e.toString()).toList();
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      tags = tagsRaw.split(',').where((e) => e.trim().isNotEmpty).toList();
    }
    if (tags.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tags.take(3).map((t) => Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            t,
            style: GoogleFonts.inter(fontSize: 9, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
        )).toList(),
      ),
    );
  }

  void _showFilterSheet() {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final ctrl = TextEditingController(text: ref.read(_productTagFilterProvider));
    
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lọc sản phẩm', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 16),
            TextFormField(
              controller: ctrl,
              style: GoogleFonts.inter(color: c.textPrimary),
              decoration: InputDecoration(
                labelText: 'Tìm theo Thẻ (Tags)',
                hintText: 'Nhập thẻ để lọc...',
                filled: true,
                fillColor: c.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.divider)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(_productTagFilterProvider.notifier).set(ctrl.text.trim());
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text('Áp dụng bộ lọc', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
