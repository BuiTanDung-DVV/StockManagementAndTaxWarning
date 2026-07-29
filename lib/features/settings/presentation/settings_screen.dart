import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/costing_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/system_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(costingProvider.notifier).loadCostingMethod(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final shopAsync = ref.watch(shopProfileProvider);
    final shopState = ref.watch(shopProvider);
    final auth = ref.watch(authProvider);
    final notifications = ref.watch(notificationProvider);
    final brandColor = ref.watch(brandColorProvider);
    final costing = ref.watch(costingProvider);
    final canManageSettings =
        shopState.isOwner || shopState.hasPermission('settings');
    final canManageStaff = shopState.isOwner || auth.isShopOwner;

    final sections = <_SettingsSectionData>[
      _SettingsSectionData(
        title: 'Tài khoản & bảo mật',
        entries: [
          _SettingsEntry(
            label: 'Thông tin cá nhân',
            description: 'Cập nhật hồ sơ và thông tin liên hệ của tài khoản.',
            onTap: () => context.push('/profile'),
          ),
          _SettingsEntry(
            label: 'Đổi mật khẩu',
            description: 'Thiết lập mật khẩu mới cho tài khoản đang đăng nhập.',
            onTap: () => context.push('/change-password'),
          ),
          if (shopState.userShops.length > 1)
            _SettingsEntry(
              label: 'Chuyển cửa hàng',
              description:
                  'Đang xem: ${shopState.currentShopName ?? 'Tất cả cửa hàng'}.',
              onTap: () => _showShopSwitcher(context, shopState),
            ),
        ],
      ),
      if (canManageStaff)
        _SettingsSectionData(
          title: 'Nhân viên & phân quyền',
          entries: [
            _SettingsEntry(
              label: 'Danh sách nhân viên',
              description: 'Quản lý thành viên đang làm việc tại cửa hàng.',
              onTap: () => context.push('/staff'),
            ),
            _SettingsEntry(
              label: 'Vai trò và quyền truy cập',
              description: 'Thiết lập phạm vi thao tác theo từng vai trò.',
              onTap: () => context.push('/roles'),
            ),
          ],
        ),
      _SettingsSectionData(
        title: 'Hàng hóa & kho vận',
        entries: [
          _SettingsEntry(
            label: 'Danh mục sản phẩm',
            description: 'Chuẩn hóa nhóm hàng phục vụ tra cứu và báo cáo.',
            badge: 'Sắp có',
            onTap: () => _showComingSoon('Quản lý danh mục sản phẩm'),
          ),
          if (canManageSettings)
            _SettingsEntry(
              label: 'Nhật ký hoạt động',
              description:
                  'Tra cứu thao tác quan trọng đã thực hiện trong hệ thống.',
              onTap: () => context.push('/activity-logs'),
            ),
          if (canManageSettings)
            _SettingsEntry(
              label: 'Phương pháp tính giá vốn',
              description: costing.isLoading
                  ? 'Đang tải cấu hình…'
                  : costing.method == 'FIFO'
                  ? 'Đang dùng: Nhập trước – xuất trước (FIFO).'
                  : 'Đang dùng: Bình quân gia quyền (AVG).',
              onTap: costing.isLoading
                  ? null
                  : () => _showCostingMethodPicker(context),
            ),
        ],
      ),
      _SettingsSectionData(
        title: 'Cửa hàng & thanh toán',
        entries: [
          if (canManageSettings)
            _SettingsEntry(
              label: 'Thông tin cửa hàng',
              description:
                  'Cập nhật tên, địa chỉ, mã số thuế và thông tin liên hệ.',
              onTap: () => context.push('/shop-profile'),
            ),
          if (canManageSettings)
            _SettingsEntry(
              label: 'VietQR và tài khoản nhận tiền',
              description: 'Thiết lập tài khoản ngân hàng dùng khi thanh toán.',
              onTap: () => context.push('/payment-config'),
            ),
          _SettingsEntry(
            label: 'Mẫu hóa đơn in',
            description:
                'Tùy chỉnh nội dung và nhận diện trên chứng từ bán hàng.',
            badge: 'Sắp có',
            onTap: () => _showComingSoon('Tùy biến mẫu hóa đơn'),
          ),
          _SettingsEntry(
            label: 'Đơn vị vận chuyển',
            description: 'Quản lý đối tác giao hàng và cấu hình vận chuyển.',
            badge: 'Sắp có',
            onTap: () => _showComingSoon('Quản lý đơn vị vận chuyển'),
          ),
        ],
      ),
      _SettingsSectionData(
        title: 'Thuế & trợ giúp nghiệp vụ',
        entries: [
          if (canManageSettings)
            _SettingsEntry(
              label: 'Cấu hình thuế',
              description:
                  'Thiết lập thông số dùng trong chức năng hỗ trợ tính thuế.',
              onTap: () => context.push('/tax-config'),
            ),
          _SettingsEntry(
            label: 'Kênh hỗ trợ thuế',
            description:
                'Xem đầu mối và tài liệu hỗ trợ khi cần làm rõ nghiệp vụ.',
            onTap: () => context.push('/tax-support'),
          ),
          _SettingsEntry(
            label: 'Nguồn tài liệu tham khảo',
            description:
                'Quản lý nguồn kiến thức được dùng trong phần trợ giúp.',
            onTap: () => context.push('/settings/ai-knowledge'),
          ),
        ],
      ),
      _SettingsSectionData(
        title: 'Hệ thống & giao diện',
        entries: [
          _SettingsEntry(
            label: 'Trung tâm thông báo',
            description: 'Xem cảnh báo vận hành và thông báo cần xử lý.',
            badge: notifications.unreadCount > 0
                ? '${notifications.unreadCount} chưa đọc'
                : null,
            onTap: () => context.push('/notifications'),
          ),
          _SettingsEntry(
            label: 'Màu giao diện',
            description: 'Đang dùng: ${brandColor.label}.',
            onTap: () => _showBrandColorPicker(context, brandColor),
          ),
          _SettingsEntry(
            label: 'Sao lưu và khôi phục',
            description: 'Tạo bản sao dữ liệu và khôi phục khi có sự cố.',
            badge: 'Sắp có',
            onTap: () => _showComingSoon('Sao lưu và khôi phục dữ liệu'),
          ),
          _SettingsEntry(
            label: 'Thông tin phần mềm',
            description: 'Xem phiên bản và thông tin sản phẩm.',
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    ];

    final query = _searchQuery.trim().toLowerCase();
    final filteredSections = sections
        .map(
          (section) => _SettingsSectionData(
            title: section.title,
            entries: section.entries.where((entry) {
              if (query.isEmpty) return true;
              return entry.label.toLowerCase().contains(query) ||
                  entry.description.toLowerCase().contains(query) ||
                  section.title.toLowerCase().contains(query);
            }).toList(),
          ),
        )
        .where((section) => section.entries.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: AppResponsiveContent(
          maxWidth: 1200,
          verticalPadding: AppSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPageHeader(
                title: 'Cài đặt hệ thống',
                subtitle:
                    'Quản lý tài khoản, cửa hàng, phân quyền và các cấu hình nghiệp vụ.',
                dense: true,
                action: featureGuideButton(context, 'settings'),
                compactAction: featureGuideButton(context, 'settings'),
              ),
              _SettingsProfileCard(
                shopAsync: shopAsync,
                user: auth.user,
                shopState: shopState,
                onOpenProfile: () => context.push('/profile'),
                onSwitchShop: shopState.userShops.length > 1
                    ? () => _showShopSwitcher(context, shopState)
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilterBar(
                searchHint: 'Tìm nhanh một thiết lập',
                onSearchChanged: (value) {
                  if (value != _searchQuery) {
                    setState(() => _searchQuery = value);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              if (filteredSections.isEmpty)
                AppCardContainer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Center(
                      child: Text(
                        'Không tìm thấy thiết lập phù hợp.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                AppFillGrid(
                  minItemWidth: 420,
                  maxColumns: 2,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final section in filteredSections)
                      _SettingsSection(section: section),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmLogout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.55),
                    ),
                  ),
                  child: const Text('Đăng xuất tài khoản'),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ToastService.showSuccess(
      '$feature đang được chuẩn bị cho phiên bản tiếp theo.',
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await AppConfirmModal.show(
      context,
      title: 'Xác nhận đăng xuất',
      message:
          'Bạn có chắc muốn đăng xuất khỏi ứng dụng? Hãy hoàn tất các thay đổi chưa lưu trước khi tiếp tục.',
      confirmText: 'Đăng xuất',
      cancelText: 'Ở lại',
      isDestructive: true,
    );
    if (confirmed != true) return;

    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  void _showShopSwitcher(BuildContext context, ShopState shopState) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colors = AppThemeColors.of(sheetContext);
        final availableShops = shopState.userShops
            .where(
              (shop) => shop['status'] == 'ACTIVE' && shop['isActive'] != false,
            )
            .toList();
        final canViewAll = availableShops.any(
          (shop) => shop['memberType'] == 'OWNER',
        );

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chuyển cửa hàng',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Dữ liệu trên màn hình sẽ đổi theo cửa hàng được chọn.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: ListView(
                      children: [
                        if (canViewAll)
                          _ShopOption(
                            title: 'Tất cả cửa hàng',
                            subtitle: 'Xem dữ liệu tổng hợp của các cửa hàng.',
                            selected: shopState.isAllShops,
                            onTap: () {
                              ref.read(shopProvider.notifier).switchShop(-1);
                              Navigator.pop(sheetContext);
                            },
                          ),
                        for (final shop in availableShops)
                          _ShopOption(
                            title:
                                shop['shopName']?.toString() ??
                                'Cửa hàng #${shop['shopId']}',
                            subtitle: shop['memberType'] == 'OWNER'
                                ? 'Chủ sở hữu'
                                : (shop['role']?['name']?.toString() ??
                                      'Nhân viên'),
                            selected:
                                parseShopRecordId(shop['shopId']) ==
                                    shopState.currentShopId &&
                                !shopState.isAllShops,
                            onTap: () {
                              final shopId = int.tryParse(
                                shop['shopId']?.toString() ?? '',
                              );
                              if (shopId == null) return;
                              ref
                                  .read(shopProvider.notifier)
                                  .switchShop(shopId);
                              Navigator.pop(sheetContext);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBrandColorPicker(BuildContext context, AppBrandColor current) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colors = AppThemeColors.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn màu giao diện',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Màu được áp dụng cho nút chính và trạng thái đang chọn.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final item in AppBrandColor.values)
                      _BrandColorOption(
                        item: item,
                        selected: item == current,
                        onTap: () {
                          ref
                              .read(brandColorProvider.notifier)
                              .setBrandColor(item);
                          Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCostingMethodPicker(BuildContext context) {
    final costing = ref.read(costingProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final colors = AppThemeColors.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phương pháp tính giá vốn',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Cấu hình này được dùng để tính giá vốn và lợi nhuận.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.lg),
                _CostingOption(
                  title: 'Bình quân gia quyền (AVG)',
                  description: 'Tính giá bình quân từ các lô hàng còn tồn kho.',
                  selected: costing.method == 'AVG',
                  onTap: () => _updateCostingMethod(sheetContext, 'AVG'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _CostingOption(
                  title: 'Nhập trước – xuất trước (FIFO)',
                  description:
                      'Ưu tiên giá của lô nhập kho sớm hơn khi xuất bán.',
                  selected: costing.method == 'FIFO',
                  onTap: () => _updateCostingMethod(sheetContext, 'FIFO'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateCostingMethod(
    BuildContext sheetContext,
    String method,
  ) async {
    Navigator.pop(sheetContext);
    final success = await ref
        .read(costingProvider.notifier)
        .updateCostingMethod(method);
    if (success) {
      ToastService.showSuccess('Đã cập nhật phương pháp tính giá vốn.');
    } else {
      ToastService.showError('Không thể cập nhật phương pháp tính giá vốn.');
    }
  }

  Future<void> _showAbout(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationIcon: const AppAssetIcon(
        assetPath: AppAssets.appIcon,
        size: 44,
        semanticLabel: 'SmartStock',
      ),
      applicationName: 'SmartStock',
      applicationVersion: packageInfo.version,
      applicationLegalese: '© 2026 SmartStock.',
      children: [
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Ứng dụng hỗ trợ quản lý bán hàng, tồn kho, tài chính và cảnh báo nghiệp vụ thuế cho hộ kinh doanh.',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
      ],
    );
  }
}

class _SettingsProfileCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> shopAsync;
  final Map<String, dynamic>? user;
  final ShopState shopState;
  final VoidCallback onOpenProfile;
  final VoidCallback? onSwitchShop;

  const _SettingsProfileCard({
    required this.shopAsync,
    required this.user,
    required this.shopState,
    required this.onOpenProfile,
    required this.onSwitchShop,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final fullName = user?['fullName']?.toString().trim();
    final displayName = fullName == null || fullName.isEmpty
        ? 'Người dùng SmartStock'
        : fullName;

    return AppCardContainer(
      child: shopAsync.when(
        data: (shop) => LayoutBuilder(
          builder: (context, constraints) {
            final shopName =
                shop['shopName']?.toString() ??
                shop['name']?.toString() ??
                'Cửa hàng của tôi';
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'MST: ${shop['taxCode']?.toString() ?? 'Chưa cập nhật'}'
                  '${shopState.isOwner && shopState.shopCode != null ? '  ·  Mã CH: ${shopState.shopCode}' : ''}',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            );
            final actions = Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: onOpenProfile,
                  child: const Text('Xem hồ sơ'),
                ),
                if (onSwitchShop != null)
                  OutlinedButton(
                    onPressed: onSwitchShop,
                    child: const Text('Đổi cửa hàng'),
                  ),
              ],
            );

            if (constraints.maxWidth < 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppAssetIcon(
                        assetPath: AppAssets.appIcon,
                        size: 44,
                        semanticLabel: 'SmartStock',
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                const AppAssetIcon(
                  assetPath: AppAssets.appIcon,
                  size: 48,
                  semanticLabel: 'SmartStock',
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: details),
                const SizedBox(width: AppSpacing.md),
                actions,
              ],
            );
          },
        ),
        loading: () => const SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => Row(
          children: [
            const AppAssetIcon(
              assetPath: AppAssets.appIcon,
              size: 44,
              semanticLabel: 'SmartStock',
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Chưa tải được thông tin cửa hàng.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onOpenProfile,
              child: const Text('Xem hồ sơ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionData {
  final String title;
  final List<_SettingsEntry> entries;

  const _SettingsSectionData({required this.title, required this.entries});
}

class _SettingsEntry {
  final String label;
  final String description;
  final String? badge;
  final VoidCallback? onTap;

  const _SettingsEntry({
    required this.label,
    required this.description,
    this.badge,
    required this.onTap,
  });
}

class _SettingsSection extends StatelessWidget {
  final _SettingsSectionData section;

  const _SettingsSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return AppCardContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              section.title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Divider(height: 1, color: colors.divider),
          for (var index = 0; index < section.entries.length; index++)
            _SettingsActionRow(
              entry: section.entries[index],
              showDivider: index < section.entries.length - 1,
            ),
        ],
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final _SettingsEntry entry;
  final bool showDivider;

  const _SettingsActionRow({required this.entry, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return InkWell(
      onTap: entry.onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: colors.divider))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: TextStyle(
                      color: entry.onTap == null
                          ? colors.textMuted
                          : colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    entry.description,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            if (entry.badge != null)
              AppStatusBadge(
                label: entry.badge!,
                color: entry.badge == 'Sắp có'
                    ? colors.textMuted
                    : Theme.of(context).colorScheme.primary,
              )
            else
              Text(
                entry.onTap == null ? 'Đang tải' : 'Mở',
                style: TextStyle(
                  color: entry.onTap == null
                      ? colors.textMuted
                      : Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShopOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ShopOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? primary.withValues(alpha: 0.07) : colors.card,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: selected ? primary : colors.divider),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  AppStatusBadge(label: 'Đang dùng', color: primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandColorOption extends StatelessWidget {
  final AppBrandColor item;
  final bool selected;
  final VoidCallback onTap;

  const _BrandColorOption({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? item.color : colors.divider,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SizedBox(
          width: 148,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CostingOption extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _CostingOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary.withValues(alpha: 0.07) : colors.card,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? primary : colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.md),
                AppStatusBadge(label: 'Đang dùng', color: primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
