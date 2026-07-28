import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/customer_provider.dart';

final _customerCurrencyFormat = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final listAsync = ref.watch(
      customerListProvider((
        page: 1,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
      )),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: AppResponsiveContent(
        maxWidth: 1320,
        verticalPadding: AppSpacing.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Khách hàng',
              subtitle:
                  'Tra cứu thông tin liên hệ, nhóm khách và công nợ phát sinh.',
              action: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => showFeatureGuide(context, 'customer_list'),
                    child: const Text('Hướng dẫn'),
                  ),
                  FilledButton(
                    onPressed: () => context.push('/customers/form'),
                    child: const Text('Thêm khách hàng'),
                  ),
                ],
              ),
            ),
            FilterBar(
              searchHint: 'Tìm theo tên hoặc số điện thoại',
              onSearchChanged: (value) {
                if (value != _searchQuery) {
                  setState(() => _searchQuery = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: listAsync.when(
                data: (data) {
                  final customers = ((data['items'] as List?) ?? const [])
                      .whereType<Map>()
                      .map((item) => Map<String, dynamic>.from(item))
                      .toList();
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(customerListProvider),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (customers.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              AppCardContainer(
                                child: AppEmpty(
                                  visual: AppEmptyVisual.people,
                                  message: _searchQuery.trim().isEmpty
                                      ? 'Chưa có khách hàng'
                                      : 'Không tìm thấy khách hàng phù hợp',
                                  subtitle: _searchQuery.trim().isEmpty
                                      ? 'Thêm khách hàng để lưu thông tin và theo dõi lịch sử giao dịch.'
                                      : 'Hãy kiểm tra lại tên hoặc số điện thoại đã nhập.',
                                  action: _searchQuery.trim().isEmpty
                                      ? FilledButton(
                                          onPressed: () =>
                                              context.push('/customers/form'),
                                          child: const Text(
                                            'Thêm khách hàng đầu tiên',
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          );
                        }

                        if (constraints.maxWidth < 760) {
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: customers.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) =>
                                _MobileCustomerCard(
                                  customer: customers[index],
                                  onTap: () => context.push(
                                    '/customers/${customers[index]['id']}',
                                  ),
                                ),
                          );
                        }

                        return AppCardContainer(
                          padding: EdgeInsets.zero,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: customers.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return const _CustomerTableHeader();
                              }
                              final customer = customers[index - 1];
                              return _DesktopCustomerRow(
                                customer: customer,
                                showDivider: index < customers.length,
                                onTap: () => context.push(
                                  '/customers/${customer['id']}',
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const ShimmerList(),
                error: (error, _) => AppError(
                  message: 'Không thể tải danh sách khách hàng: $error',
                  onRetry: () => ref.invalidate(customerListProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTableHeader extends StatelessWidget {
  const _CustomerTableHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final style = TextStyle(
      color: colors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );

    return Container(
      color: colors.cardAlt,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('KHÁCH HÀNG', style: style)),
          Expanded(flex: 3, child: Text('PHÂN NHÓM', style: style)),
          Expanded(
            flex: 2,
            child: Text('CÔNG NỢ', textAlign: TextAlign.right, style: style),
          ),
          const SizedBox(width: 76),
        ],
      ),
    );
  }
}

class _DesktopCustomerRow extends StatelessWidget {
  final Map<String, dynamic> customer;
  final bool showDivider;
  final VoidCallback onTap;

  const _DesktopCustomerRow({
    required this.customer,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final debt = asDouble(customer['totalDebt'] ?? customer['balance']);
    final tags = _customerTags(customer, debt);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: colors.divider))
              : null,
        ),
        child: Row(
          children: [
            Expanded(flex: 4, child: _CustomerIdentity(customer: customer)),
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final tag in tags.take(3))
                    AppStatusBadge(
                      label: tag,
                      color: _customerTagColor(tag, context),
                    ),
                  if (tags.isEmpty)
                    Text(
                      'Chưa phân nhóm',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                debt > 0 ? _customerCurrencyFormat.format(debt) : '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: debt > 0 ? AppColors.danger : colors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              width: 76,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: onTap, child: const Text('Xem')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileCustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onTap;

  const _MobileCustomerCard({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final debt = asDouble(customer['totalDebt'] ?? customer['balance']);
    final tags = _customerTags(customer, debt);

    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CustomerIdentity(customer: customer),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final tag in tags.take(3))
                      AppStatusBadge(
                        label: tag,
                        color: _customerTagColor(tag, context),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Công nợ',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          debt > 0
                              ? _customerCurrencyFormat.format(debt)
                              : 'Không có',
                          style: TextStyle(
                            color: debt > 0
                                ? AppColors.danger
                                : colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: onTap, child: const Text('Xem hồ sơ')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerIdentity extends StatelessWidget {
  final Map<String, dynamic> customer;

  const _CustomerIdentity({required this.customer});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final name = customer['name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? 'Khách hàng' : name;
    final initial = displayName.characters.first.toUpperCase();

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.cardAlt,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: colors.divider),
          ),
          child: Text(
            initial,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                customer['phone']?.toString().trim().isNotEmpty == true
                    ? customer['phone'].toString()
                    : 'Chưa cập nhật số điện thoại',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

List<String> _customerTags(Map<String, dynamic> customer, double debt) {
  final tags = <String>[];
  final rawTags = customer['tags'];
  if (rawTags is List) {
    tags.addAll(rawTags.map((item) => item.toString().trim()));
  } else if (rawTags is String && rawTags.trim().isNotEmpty) {
    tags.addAll(
      rawTags
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    );
  }

  if (customer['customerType'] == 'VIP' && !tags.contains('VIP')) {
    tags.insert(0, 'VIP');
  }
  if (debt > 0 && !tags.contains('Đang nợ')) {
    tags.insert(0, 'Đang nợ');
  }
  if (_isRecent(customer['createdAt'] ?? customer['created_at']) &&
      !tags.contains('Mới')) {
    tags.insert(0, 'Mới');
  }

  return tags.where((tag) => tag.isNotEmpty).toSet().toList();
}

Color _customerTagColor(String tag, BuildContext context) {
  if (tag == 'Đang nợ') return AppColors.danger;
  if (tag == 'VIP') return AppColors.warning;
  if (tag == 'Mới') return AppColors.info;
  return Theme.of(context).colorScheme.primary;
}

bool _isRecent(dynamic value) {
  if (value == null) return false;
  final createdAt = DateTime.tryParse(value.toString());
  if (createdAt == null) return false;
  return DateTime.now().difference(createdAt).inDays <= 30;
}
