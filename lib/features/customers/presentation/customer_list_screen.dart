import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/filter_bar.dart';
import '../providers/customer_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final listAsync = ref.watch(customerListProvider((page: 1, search: _searchQuery.isEmpty ? null : _searchQuery)));

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Danh sách khách hàng',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: tc.textPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          featureGuideButton(context, 'customer_list'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customers/form'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text('Thêm khách hàng', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: listAsync.when(
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          if (items.isEmpty) {
            return const AppEmpty(
              message: 'Chưa có khách hàng', 
              subtitle: 'Hãy thêm khách hàng đầu tiên để bắt đầu lưu trữ giao dịch'
            );
          }
          return Column(
            children: [
              FilterBar(
                searchHint: 'Tìm theo tên, điện thoại...',
                onSearchChanged: (v) => setState(() => _searchQuery = v),
              ),
              Expanded(
                child: Container(
                  color: tc.card,
                  child: RefreshIndicator(
                    color: theme.colorScheme.primary,
                    onRefresh: () async => ref.invalidate(customerListProvider),
                    child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: tc.divider.withValues(alpha: 0.5)),
              itemBuilder: (_, i) {
                final cust = items[i];
                final debt = asDouble(cust['totalDebt'] ?? cust['balance']);
                final initialChar = (cust['name'] ?? 'K')[0].toUpperCase();

                return GestureDetector(
                  onTap: () => context.push('/customers/${cust['id']}'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        // Elegant Squircle Avatar with Dynamic Brand Pale blending
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initialChar,
                            style: GoogleFonts.outfit(
                              color: theme.colorScheme.primary, 
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cust['name'] ?? '', 
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 14,
                                  color: tc.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.phone_iphone_rounded, size: 12, color: tc.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    cust['phone'] ?? '(Chưa cập nhật)', 
                                    style: TextStyle(
                                      fontSize: 11, 
                                      color: tc.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (cust['tags'] != null || debt > 0 || _isNew(cust['createdAt']) || cust['customerType'] == 'VIP') ...[
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildTagsRow(cust, debt, tc, theme)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        if (debt > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Công nợ',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: tc.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currFmt.format(debt), 
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800, 
                                  fontSize: 13, 
                                  color: debt > 5000000 ? AppColors.danger : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
                      ),
                    ),
                  ), // RefreshIndicator
                ), // Expanded
              ], // Children array
          ); // Column
        },
        loading: () => const ShimmerList(),
        error: (e, _) => AppError(
          message: 'Lỗi: $e', 
          onRetry: () => ref.invalidate(customerListProvider)
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

  Widget _buildTagsRow(Map<String, dynamic> cust, double debt, AppThemeColors c, ThemeData theme) {
    List<String> tags = [];
    final tagsRaw = cust['tags'];
    if (tagsRaw is List) {
      tags = tagsRaw.map((e) => e.toString()).toList();
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      tags = tagsRaw.split(',').where((e) => e.trim().isNotEmpty).toList();
    }

    // Auto tags
    if (cust['customerType'] == 'VIP') {
      if (!tags.contains('VIP')) tags.insert(0, 'VIP');
    }
    if (debt > 0) {
      if (!tags.contains('Đang nợ')) tags.insert(0, 'Đang nợ');
    }
    if (_isNew(cust['createdAt'] ?? cust['created_at'])) {
      if (!tags.contains('Mới')) tags.insert(0, 'Mới');
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tags.take(3).map((t) {
          Color bgColor = theme.colorScheme.primary.withValues(alpha: 0.1);
          Color textColor = theme.colorScheme.primary;

          if (t == 'Đang nợ') {
            bgColor = AppColors.danger.withValues(alpha: 0.1);
            textColor = AppColors.danger;
          } else if (t == 'VIP') {
            bgColor = Colors.purple.withValues(alpha: 0.1);
            textColor = Colors.purple;
          } else if (t == 'Mới') {
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
