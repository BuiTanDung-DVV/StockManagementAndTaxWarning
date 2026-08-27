import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

int paginationValue(
  Map<String, dynamic> data,
  String key, {
  required int fallback,
}) {
  final value = data[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class AppPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final String itemLabel;
  final ValueChanged<int> onPageChanged;
  final double trailingSafeSpace;

  const AppPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemLabel,
    required this.onPageChanged,
    this.trailingSafeSpace = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final safeTotalPages = totalPages < 1 ? 1 : totalPages;
    final safeCurrentPage = currentPage.clamp(1, safeTotalPages);
    final canGoBack = safeCurrentPage > 1;
    final canGoNext = safeCurrentPage < safeTotalPages;

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md + trailingSafeSpace,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = Text(
            '$totalItems $itemLabel · Trang $safeCurrentPage/$safeTotalPages',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: canGoBack
                    ? () => onPageChanged(safeCurrentPage - 1)
                    : null,
                child: const Text('Trước'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonal(
                onPressed: canGoNext
                    ? () => onPageChanged(safeCurrentPage + 1)
                    : null,
                child: const Text('Sau'),
              ),
            ],
          );

          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: summary),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: controls.children[0]),
                    controls.children[1],
                    Expanded(child: controls.children[2]),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: summary),
              controls,
            ],
          );
        },
      ),
    );
  }
}
