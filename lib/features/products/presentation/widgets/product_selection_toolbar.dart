import '../../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class ProductSelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onClearSelection;
  final Future<void> Function() onExport;
  final bool isExporting;
  final bool canExport;

  const ProductSelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.onClearSelection,
    required this.onExport,
    this.isExporting = false,
    this.canExport = true,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0) return const SizedBox.shrink();

    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 460;

        final label = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              Icons.check_circle_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                'Đã chọn $selectedCount sản phẩm',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        );

        final actions = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            if (canExport) ...[
              OutlinedButton.icon(
                key: const Key('product-bulk-export-xlsx-button'),
                onPressed: isExporting ? null : onExport,
                icon: isExporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppIcon(Icons.download_rounded, size: 16),
                label: const Text('Xuất Excel'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
            TextButton(
              key: const Key('product-bulk-clear-selection-button'),
              onPressed: onClearSelection,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              child: const Text('Bỏ chọn'),
            ),
          ],
        );

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: isNarrow
              ? Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [label, actions],
                )
              : Row(
                  children: [
                    Expanded(child: label),
                    actions,
                  ],
                ),
        );
      },
    );
  }
}
