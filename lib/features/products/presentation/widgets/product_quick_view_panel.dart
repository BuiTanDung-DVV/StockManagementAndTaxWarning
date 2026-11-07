import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/app_icon.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/utils/type_parser.dart';
import '../../providers/product_provider.dart';
import 'product_details_content.dart';

/// Keeps navigation available while the product details scroll independently.
class ProductQuickViewPanel extends ConsumerWidget {
  const ProductQuickViewPanel({
    super.key,
    required this.product,
    required this.onClose,
    required this.onViewFullDetail,
  });

  final Map<String, dynamic> product;
  final VoidCallback onClose;
  final VoidCallback onViewFullDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final id = TypeParser.asInt(product['id']);
    final detail = ref.watch(productDetailProvider(id));

    Widget content(Map<String, dynamic> data, {Widget? banner}) =>
        SingleChildScrollView(
          key: const Key('product-quick-view-scroll'),
          padding: const EdgeInsets.all(24),
          child: ProductDetailsContent(
            product: data,
            isQuickView: true,
            showQuickViewActions: false,
            banner: banner,
          ),
        );

    return Material(
      color: c.card,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Xem nhanh sản phẩm',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('product-quick-view-close-button'),
                    tooltip: 'Đóng (Esc)',
                    onPressed: onClose,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: BorderSide.none,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const AppIcon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.divider),
            Expanded(
              child: detail.when(
                data: (data) => content({...product, ...data}),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => content(
                  product,
                  banner: AppInlineError(
                    message: 'Không thể tải chi tiết sản phẩm đầy đủ.',
                    onRetry: () => ref.invalidate(productDetailProvider(id)),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: c.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(onPressed: onClose, child: const Text('Đóng')),
                  FilledButton.icon(
                    key: const Key('product-quick-view-full-detail-button'),
                    onPressed: onViewFullDetail,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const AppIcon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Xem chi tiết đầy đủ'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
