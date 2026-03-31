import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// ─── Reusable Shimmer Skeleton Widgets ───

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const ShimmerBox({super.key, required this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Shimmer wrapper that auto-detects theme
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? c.surface : Colors.grey.shade300,
      highlightColor: isDark ? c.cardAlt : Colors.grey.shade100,
      child: child,
    );
  }
}

/// Skeleton for a summary card (used on Dashboard)
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShimmerBox(width: 80, height: 12),
          const SizedBox(height: 12),
          ShimmerBox(width: 120, height: 24),
          const SizedBox(height: 8),
          ShimmerBox(width: 60, height: 10),
        ]),
      ),
    );
  }
}

/// Skeleton for a list tile item
class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShimmerBox(width: 160, height: 14),
            const SizedBox(height: 8),
            ShimmerBox(width: 100, height: 10),
          ])),
          ShimmerBox(width: 50, height: 14),
        ]),
      ),
    );
  }
}

/// Shimmer list — multiple ShimmerListTile
class ShimmerList extends StatelessWidget {
  final int count;
  const ShimmerList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return Column(children: List.generate(count, (_) => const ShimmerListTile()));
  }
}

/// Full dashboard skeleton (4 cards + actions)
class ShimmerDashboard extends StatelessWidget {
  const ShimmerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Header shimmer
        AppShimmer(child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShimmerBox(width: 150, height: 14),
            const SizedBox(height: 8),
            ShimmerBox(width: 100, height: 22),
          ])),
          ShimmerBox(width: 36, height: 36, radius: 18),
        ])),
        const SizedBox(height: 24),

        // 4 summary cards in grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: List.generate(4, (_) => const ShimmerCard()),
        ),
        const SizedBox(height: 24),

        // Quick actions shimmer
        AppShimmer(child: Column(children: [
          Align(alignment: Alignment.centerLeft, child: ShimmerBox(width: 120, height: 16)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(4, (_) =>
            Column(children: [
              ShimmerBox(width: 48, height: 48, radius: 12),
              const SizedBox(height: 6),
              ShimmerBox(width: 40, height: 10),
            ]),
          )),
        ])),
      ]),
    );
  }
}
