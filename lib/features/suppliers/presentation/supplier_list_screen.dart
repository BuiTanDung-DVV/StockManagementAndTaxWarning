import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/supplier_provider.dart';

class SupplierListScreen extends ConsumerStatefulWidget {
  const SupplierListScreen({super.key});

  @override
  ConsumerState<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends ConsumerState<SupplierListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final listAsync = ref.watch(
      supplierListProvider((
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
              title: 'Nhà cung cấp',
              subtitle:
                  'Quản lý đối tác, thông tin thuế và điều khoản thanh toán.',
              action: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => showFeatureGuide(context, 'supplier_list'),
                    child: const Text('Hướng dẫn'),
                  ),
                  FilledButton(
                    onPressed: () => context.push('/suppliers/form'),
                    child: const Text('Thêm nhà cung cấp'),
                  ),
                ],
              ),
            ),
            FilterBar(
              searchHint: 'Tìm theo tên, mã số thuế hoặc số điện thoại',
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
                  final suppliers = ((data['items'] as List?) ?? const [])
                      .whereType<Map>()
                      .map((item) => Map<String, dynamic>.from(item))
                      .toList();

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(supplierListProvider),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (suppliers.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              AppCardContainer(
                                child: AppEmpty(
                                  message: _searchQuery.trim().isEmpty
                                      ? 'Chưa có nhà cung cấp'
                                      : 'Không tìm thấy nhà cung cấp phù hợp',
                                  subtitle: _searchQuery.trim().isEmpty
                                      ? 'Thêm đối tác để quản lý nhập hàng và điều khoản thanh toán.'
                                      : 'Hãy kiểm tra lại tên, mã số thuế hoặc số điện thoại.',
                                  action: _searchQuery.trim().isEmpty
                                      ? FilledButton(
                                          onPressed: () =>
                                              context.push('/suppliers/form'),
                                          child: const Text(
                                            'Thêm nhà cung cấp đầu tiên',
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
                            itemCount: suppliers.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) =>
                                _MobileSupplierCard(
                                  supplier: suppliers[index],
                                  onTap: () => context.push(
                                    '/suppliers/${suppliers[index]['id']}',
                                  ),
                                ),
                          );
                        }

                        return AppCardContainer(
                          padding: EdgeInsets.zero,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: suppliers.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return const _SupplierTableHeader();
                              }
                              final supplier = suppliers[index - 1];
                              return _DesktopSupplierRow(
                                supplier: supplier,
                                showDivider: index < suppliers.length,
                                onTap: () => context.push(
                                  '/suppliers/${supplier['id']}',
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
                  message: 'Không thể tải danh sách nhà cung cấp: $error',
                  onRetry: () => ref.invalidate(supplierListProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierTableHeader extends StatelessWidget {
  const _SupplierTableHeader();

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
          Expanded(flex: 4, child: Text('NHÀ CUNG CẤP', style: style)),
          Expanded(flex: 3, child: Text('THÔNG TIN THUẾ', style: style)),
          Expanded(
            flex: 2,
            child: Text(
              'HẠN THANH TOÁN',
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
          const SizedBox(width: 76),
        ],
      ),
    );
  }
}

class _DesktopSupplierRow extends StatelessWidget {
  final Map<String, dynamic> supplier;
  final bool showDivider;
  final VoidCallback onTap;

  const _DesktopSupplierRow({
    required this.supplier,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final taxCode =
        supplier['taxCode']?.toString() ??
        supplier['tax_code']?.toString() ??
        '';
    final paymentTerm = supplier['paymentTermDays'] ?? supplier['paymentTerms'];

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
            Expanded(flex: 4, child: _SupplierIdentity(supplier: supplier)),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    taxCode.isEmpty ? 'Chưa cập nhật MST' : 'MST: $taxCode',
                    style: TextStyle(
                      color: taxCode.isEmpty
                          ? colors.textMuted
                          : colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((supplier['email']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      supplier['email'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                paymentTerm == null || paymentTerm.toString().isEmpty
                    ? '—'
                    : '${paymentTerm.toString()} ngày',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
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

class _MobileSupplierCard extends StatelessWidget {
  final Map<String, dynamic> supplier;
  final VoidCallback onTap;

  const _MobileSupplierCard({required this.supplier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final taxCode =
        supplier['taxCode']?.toString() ??
        supplier['tax_code']?.toString() ??
        '';
    final paymentTerm = supplier['paymentTermDays'] ?? supplier['paymentTerms'];
    final tags = _supplierTags(supplier);

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
              _SupplierIdentity(supplier: supplier),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final tag in tags.take(3))
                      AppStatusBadge(
                        label: tag,
                        color: tag == 'Mới'
                            ? AppColors.info
                            : Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SupplierValue(
                      label: 'Mã số thuế',
                      value: taxCode.isEmpty ? 'Chưa cập nhật' : taxCode,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _SupplierValue(
                      label: 'Hạn thanh toán',
                      value:
                          paymentTerm == null || paymentTerm.toString().isEmpty
                          ? 'Chưa thiết lập'
                          : '${paymentTerm.toString()} ngày',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onTap,
                  child: const Text('Xem hồ sơ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierIdentity extends StatelessWidget {
  final Map<String, dynamic> supplier;

  const _SupplierIdentity({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final name = supplier['name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? 'Nhà cung cấp' : name;
    final initial = displayName.characters.first.toUpperCase();
    final phone = supplier['phone']?.toString() ?? '';

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
                phone.isEmpty ? 'Chưa cập nhật số điện thoại' : phone,
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

class _SupplierValue extends StatelessWidget {
  final String label;
  final String value;

  const _SupplierValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

List<String> _supplierTags(Map<String, dynamic> supplier) {
  final tags = <String>[];
  final rawTags = supplier['tags'];
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

  if (_isRecentSupplier(supplier['createdAt'] ?? supplier['created_at']) &&
      !tags.contains('Mới')) {
    tags.insert(0, 'Mới');
  }
  return tags.where((tag) => tag.isNotEmpty).toSet().toList();
}

bool _isRecentSupplier(dynamic value) {
  if (value == null) return false;
  final createdAt = DateTime.tryParse(value.toString());
  if (createdAt == null) return false;
  return DateTime.now().difference(createdAt).inDays <= 30;
}
