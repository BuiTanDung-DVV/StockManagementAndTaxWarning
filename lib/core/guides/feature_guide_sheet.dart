import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'feature_guide_data.dart';

/// Hiển thị hướng dẫn tính năng dưới dạng BottomSheet
///
/// Sử dụng: `showFeatureGuide(context, 'dashboard')`
void showFeatureGuide(BuildContext context, String screenKey) {
  final guide = featureGuides[screenKey];
  if (guide == null) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) {
        final c = AppThemeColors.of(ctx);
        return Column(children: [
          // ── Drag handle ──
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              Text(guide.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hướng dẫn: ${guide.title}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: c.textMuted),
                onPressed: () => Navigator.pop(ctx),
              ),
            ]),
          ),
          Divider(height: 1, color: c.textMuted.withValues(alpha: 0.15)),
          // ── Guide Items ──
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: guide.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _GuideItemCard(item: guide.items[i]),
            ),
          ),
        ]);
      },
    ),
  );
}

/// Tạo nút ❓ để gắn vào AppBar actions
Widget featureGuideButton(BuildContext context, String screenKey) {
  return IconButton(
    icon: const Icon(Icons.help_outline_rounded, size: 22),
    tooltip: 'Hướng dẫn',
    onPressed: () => showFeatureGuide(context, screenKey),
  );
}

// ── Guide Item Card ──

class _GuideItemCard extends StatelessWidget {
  final FeatureGuideItem item;
  const _GuideItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.textMuted.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Giới thiệu ──
        Text(item.intro, style: const TextStyle(fontSize: 14, height: 1.5)),
        const SizedBox(height: 10),
        // ── Ví dụ ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💡', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.example,
                style: TextStyle(fontSize: 13, color: c.textSecondary, fontStyle: FontStyle.italic, height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
