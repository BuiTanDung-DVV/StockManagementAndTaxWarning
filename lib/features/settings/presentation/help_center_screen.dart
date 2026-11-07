import 'package:flutter/material.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/guides/feature_guide_data.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/search_text.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/responsive_layout.dart';

/// User-facing instructions; knowledge-source administration stays in Settings.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final entries = featureGuides.entries
        .where(
          (entry) => foldSearchText(
            entry.value.title,
          ).contains(foldSearchText(_query)),
        )
        .toList();
    return Scaffold(
      backgroundColor: AppThemeColors.of(context).bg,
      body: AppResponsiveContent(
        maxWidth: 1000,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'Trung tâm trợ giúp',
              subtitle: 'Chọn nghiệp vụ để xem cách sử dụng SmartStock.',
              showBackButton: true,
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'Tìm hướng dẫn',
                prefixIcon: AppIcon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('Không có hướng dẫn phù hợp.'))
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          leading: const AppIcon(Icons.menu_book_outlined),
                          title: Text(entry.value.title),
                          trailing: const AppIcon(Icons.chevron_right),
                          onTap: () => showFeatureGuide(context, entry.key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
