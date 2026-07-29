import 'package:flutter/material.dart';
import '../assets/app_assets.dart';
import '../theme/app_theme.dart';

class FilterBar extends StatelessWidget {
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onFilterTap;
  final Widget? trailing;
  final bool dense;
  final bool showSearchIcon;

  const FilterBar({
    super.key,
    required this.onSearchChanged,
    this.searchHint = 'Tìm kiếm...',
    this.onFilterTap,
    this.trailing,
    this.dense = false,
    this.showSearchIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    return Container(
      padding: EdgeInsets.all(dense ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final searchField = TextField(
            onChanged: onSearchChanged,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: c.textPrimary),
            decoration: InputDecoration(
              hintText: searchHint,
              hintStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: c.textMuted),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              prefixIcon: showSearchIcon
                  ? const Padding(
                      padding: EdgeInsets.only(
                        left: AppSpacing.sm,
                        right: AppSpacing.xs,
                      ),
                      child: AppAssetIcon(
                        assetPath: AppAssets.search,
                        size: 18,
                        semanticLabel: 'Tìm kiếm',
                      ),
                    )
                  : null,
              prefixIconConstraints: showSearchIcon
                  ? const BoxConstraints(minWidth: 42, minHeight: 42)
                  : null,
            ),
          );
          final filterButton = onFilterTap == null
              ? null
              : OutlinedButton(
                  onPressed: onFilterTap,
                  child: const Text('Bộ lọc'),
                );

          if (constraints.maxWidth < 520 && trailing != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    ?filterButton,
                    if (filterButton != null)
                      const SizedBox(width: AppSpacing.sm),
                    Expanded(child: trailing!),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              if (filterButton != null) ...[
                const SizedBox(width: AppSpacing.sm),
                filterButton,
              ],
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: trailing!),
              ],
            ],
          );
        },
      ),
    );
  }
}
