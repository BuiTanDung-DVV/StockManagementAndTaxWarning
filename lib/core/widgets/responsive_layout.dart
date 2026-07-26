import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Keeps page spacing proportional to the actual space allocated by the shell.
///
/// The child fills compact windows and is capped on very wide displays so data
/// remains readable. Individual screens can still override every size.
class AppResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double compactPadding;
  final double mediumPadding;
  final double expandedPadding;
  final double verticalPadding;

  const AppResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1440,
    this.compactPadding = AppSpacing.md,
    this.mediumPadding = AppSpacing.lg,
    this.expandedPadding = AppSpacing.xl,
    this.verticalPadding = AppSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final horizontalPadding = availableWidth < 600
            ? compactPadding
            : availableWidth < AppBreakpoints.expandedNavigation
            ? mediumPadding
            : expandedPadding;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A reusable grid whose children always fill the available row width.
///
/// Column count is calculated from the parent constraints instead of the
/// physical device, so it also works in resizable browser and desktop windows.
class AppFillGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;
  final double? itemHeight;

  const AppFillGrid({
    super.key,
    required this.children,
    this.minItemWidth = 240,
    this.maxColumns = 4,
    this.spacing = AppSpacing.md,
    this.runSpacing = AppSpacing.md,
    this.itemHeight,
  }) : assert(minItemWidth > 0),
       assert(maxColumns > 0);

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final calculatedColumns =
            ((availableWidth + spacing) / (minItemWidth + spacing)).floor();
        final columnCount = math.min(
          children.length,
          calculatedColumns.clamp(1, maxColumns),
        );

        if (itemHeight != null) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: runSpacing,
              mainAxisExtent: itemHeight,
            ),
            itemBuilder: (context, index) => children[index],
          );
        }

        final itemWidth =
            (availableWidth - (columnCount - 1) * spacing) / columnCount;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
