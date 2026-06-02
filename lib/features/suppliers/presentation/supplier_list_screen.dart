import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../providers/supplier_provider.dart';

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final listAsync = ref.watch(supplierListProvider((page: 1, search: null)));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Danh Sách Nhà Cung Cấp',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'supplier_list'),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/suppliers/form'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        icon: const Icon(Icons.domain_add_rounded, color: Colors.white, size: 20),
        label: Text(
          'Thêm Đối Tác',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: listAsync.when(
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          if (items.isEmpty) {
            return const AppEmpty(
              message: 'Chưa có nhà cung cấp nào.',
              subtitle: 'Hãy đăng ký đối tác nhà cung cấp đầu tiên của bạn để nhập kho.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(supplierListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: c.divider.withValues(alpha: 0.5)),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              itemBuilder: (_, i) {
                final s = items[i];
                final name = s['name'] ?? 'Nhà cung cấp ẩn danh';
                final taxCode = s['taxCode'] ?? 'N/A';
                final term = s['paymentTermDays'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 0),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.push('/suppliers/${s['id']}'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.business_rounded,
                                color: AppColors.info,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: c.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'MST: $taxCode',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: c.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (term != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Hạn nợ: $term ngày',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: c.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  if (s['tags'] != null || _isNew(s['createdAt']))
                                    _buildTagsRow(s, c, theme),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: c.textMuted,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const ShimmerList(),
        error: (e, _) => AppError(
          message: 'Lỗi tải dữ liệu: $e',
          onRetry: () => ref.invalidate(supplierListProvider),
        ),
      ),
    );
  }

  bool _isNew(dynamic createdAtRaw) {
    if (createdAtRaw == null) return false;
    final createdAt = DateTime.tryParse(createdAtRaw.toString());
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt).inDays <= 30;
  }

  Widget _buildTagsRow(Map<String, dynamic> s, AppThemeColors c, ThemeData theme) {
    List<String> tags = [];
    final tagsRaw = s['tags'];
    if (tagsRaw is List) {
      tags = tagsRaw.map((e) => e.toString()).toList();
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      tags = tagsRaw.split(',').where((e) => e.trim().isNotEmpty).toList();
    }

    // Auto tags
    if (_isNew(s['createdAt'] ?? s['created_at'])) {
      if (!tags.contains('Mới')) tags.insert(0, 'Mới');
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tags.take(3).map((t) {
          Color bgColor = theme.colorScheme.primary.withValues(alpha: 0.1);
          Color textColor = theme.colorScheme.primary;

          if (t == 'Mới') {
            bgColor = Colors.blue.withValues(alpha: 0.1);
            textColor = Colors.blue;
          }

          return Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: textColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              t,
              style: GoogleFonts.inter(fontSize: 9, color: textColor, fontWeight: FontWeight.bold),
            ),
          );
        }).toList(),
      ),
    );
  }
}
