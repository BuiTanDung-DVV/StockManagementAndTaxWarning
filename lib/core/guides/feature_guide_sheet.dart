import 'package:flutter/material.dart';
import '../assets/app_icon.dart';
import '../assets/app_assets.dart';
import '../theme/app_theme.dart';
import 'feature_guide_data.dart';

/// Hướng dẫn ngắn: hộp thoại trên web rộng, trang kéo từ dưới trên mobile.
///
/// Sử dụng: `showFeatureGuide(context, 'dashboard')`
void showFeatureGuide(BuildContext context, String screenKey) {
  final guide = featureGuides[screenKey];
  if (guide == null) return;

  if (MediaQuery.sizeOf(context).width >= 600) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: MediaQuery.sizeOf(ctx).height - 64,
          ),
          child: _FeatureGuideContent(guide: guide),
        ),
      ),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      snap: true,
      builder: (_, controller) =>
          _FeatureGuideContent(guide: guide, scrollController: controller),
    ),
  );
}

/// Tác vụ hướng dẫn có nhãn trên desktop, tooltip trên màn hẹp.
Widget featureGuideButton(BuildContext context, String screenKey) {
  if (MediaQuery.sizeOf(context).width >= 800) {
    return Tooltip(
      message: 'Hướng dẫn',
      child: TextButton.icon(
        onPressed: () => showFeatureGuide(context, screenKey),
        icon: const AppAssetIcon(assetPath: AppAssets.help, size: 18),
        label: const Text('Hướng dẫn'),
      ),
    );
  }
  return IconButton(
    icon: const AppAssetIcon(
      assetPath: AppAssets.help,
      size: 20,
      semanticLabel: 'Hướng dẫn',
    ),
    tooltip: 'Hướng dẫn',
    onPressed: () => showFeatureGuide(context, screenKey),
  );
}

// ── Guide Item Card ──

class _FeatureGuideContent extends StatelessWidget {
  final FeatureGuide guide;
  final ScrollController? scrollController;
  const _FeatureGuideContent({required this.guide, this.scrollController});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HƯỚNG DẪN SỬ DỤNG',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: c.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guide.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Đóng hướng dẫn',
                onPressed: () => Navigator.pop(context),
                icon: const AppIcon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: c.divider),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            itemCount: guide.items.length,
            separatorBuilder: (_, _) => Divider(height: 25, color: c.divider),
            itemBuilder: (_, i) => _GuideItemCard(item: guide.items[i]),
          ),
        ),
      ],
    );
  }
}

class _GuideItemCard extends StatelessWidget {
  final FeatureGuideItem item;
  const _GuideItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.heading.isNotEmpty) ...[
            Text(
              item.heading,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
          ],
          // ── Giới thiệu ──
          Text(item.intro, style: const TextStyle(fontSize: 14, height: 1.5)),
          if (item.example.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ví dụ: ${item.example}',
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
