import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class FilterBar extends StatelessWidget {
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onFilterTap;
  final Widget? trailing;

  const FilterBar({
    super.key,
    required this.onSearchChanged,
    this.searchHint = 'Tìm kiếm...',
    this.onFilterTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onSearchChanged,
              style: GoogleFonts.outfit(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: GoogleFonts.outfit(color: c.textMuted),
                prefixIcon: Icon(Icons.search, color: c.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: c.inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          if (onFilterTap != null) ...[
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: c.divider),
                borderRadius: BorderRadius.circular(16),
                color: c.surface,
              ),
              child: IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                onPressed: onFilterTap,
                color: c.textSecondary,
                tooltip: 'Lọc',
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ]
        ],
      ),
    );
  }
}
