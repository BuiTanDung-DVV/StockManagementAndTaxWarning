import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';

class GlobalSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => 'Tìm kiếm sản phẩm, đơn hàng...';

  @override
  TextStyle? get searchFieldStyle => GoogleFonts.inter(fontSize: 16);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppThemeColors.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      color: c.bg,
      child: Center(
        child: Text(
          'Kết quả tìm kiếm cho "$query"',
          style: GoogleFonts.inter(color: c.textSecondary),
        ),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final c = AppThemeColors.of(context);
    if (query.isEmpty) {
      return Container(
        color: c.bg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                color: c.textMuted,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Nhập từ khóa để tìm kiếm...',
                style: GoogleFonts.inter(color: c.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: c.bg,
      child: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.search),
            title: Text('Tìm "$query" trong Sản phẩm'),
            onTap: () => showResults(context),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: Text('Tìm "$query" trong Đơn hàng'),
            onTap: () => showResults(context),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: Text('Tìm "$query" trong Khách hàng'),
            onTap: () => showResults(context),
          ),
        ],
      ),
    );
  }
}
