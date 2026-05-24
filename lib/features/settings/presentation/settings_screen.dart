import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/system_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/costing_provider.dart';
import '../../../core/guides/feature_guide_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final shopAsync = ref.watch(shopProfileProvider);
    final shopState = ref.watch(shopProvider);
    final auth = ref.watch(authProvider);
    final notifState = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Thiết Lập Hệ Thống',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'settings'),
          // Notification bell
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedNotification03, color: c.textSecondary, size: 22),
                onPressed: () => context.push('/notifications'),
              ),
              if (notifState.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    child: Text(
                      '${notifState.unreadCount}',
                      style: GoogleFonts.outfit(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Premium Profile bento card - tappable
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: shopAsync.when(
                data: (shop) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: c.divider.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.15), width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            ((auth.user?['fullName'] as String?)?.isNotEmpty == true
                                    ? (auth.user!['fullName'] as String)[0]
                                    : '?')
                                .toUpperCase(),
                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user?['fullName'] ?? 'Người dùng SmartStock',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shop['shopName'] ?? shop['name'] ?? 'Cửa hàng của tôi',
                              style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'MST: ${shop['taxCode'] ?? 'N/A'}',
                              style: GoogleFonts.inter(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w500),
                            ),
                            if (shopState.isOwner && shopState.shopCode != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Mã CH: ${shopState.shopCode}',
                                      style: GoogleFonts.outfit(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: c.textMuted, size: 20),
                    ],
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: c.divider.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            ((auth.user?['fullName'] as String?)?.isNotEmpty == true
                                    ? (auth.user!['fullName'] as String)[0]
                                    : '?')
                                .toUpperCase(),
                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user?['fullName'] ?? 'Người dùng SmartStock',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Nhấn để xem thông tin cá nhân',
                              style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: c.textMuted, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Shop switcher (multiple shops)
            if (shopState.userShops.length > 1)
              _SettingGroup(
                'Cửa hàng hiện tại',
                [
                  _SettingItem(
                    HugeIcons.strokeRoundedExchange01,
                    'Chuyển shop (${shopState.currentShopName ?? ""})',
                    () => _showShopSwitcher(context, ref, shopState),
                    c,
                  ),
                ],
                c,
              ),

            // Appearance theme toggles
            _SettingGroup(
              'Giao diện ứng dụng',
              [
                _BrandColorTile(c: c),
              ],
              c,
            ),

            // Staff & roles (Owners only)
            if (shopState.isOwner || auth.isShopOwner)
              _SettingGroup(
                'Nhân viên & Phân quyền',
                [
                  _SettingItem(HugeIcons.strokeRoundedUserMultiple, 'Quản lý danh sách nhân viên', () => context.push('/staff'), c),
                  _SettingItem(HugeIcons.strokeRoundedUserStar02, 'Thiết lập vai trò phân quyền', () => context.push('/roles'), c),
                ],
                c,
              ),

            _SettingGroup(
              'Hàng hóa & Kho vận',
              [
                _SettingItem(HugeIcons.strokeRoundedDashboardSquare01, 'Quản lý danh mục sản phẩm', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Tính năng quản lý danh mục sẽ sớm khả dụng ở bản cập nhật kế tiếp!'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }, c),
                _SettingItem(HugeIcons.strokeRoundedClock04, 'Nhật ký hoạt động hệ thống', () => context.push('/activity-logs'), c),
              ],
              c,
            ),

            _CostingMethodTile(c: c),

            _SettingGroup(
              'Cửa hàng & Thanh toán',
              [
                _SettingItem(HugeIcons.strokeRoundedStore01, 'Thông tin cấu hình cửa hàng', () => context.push('/shop-profile'), c),
                _SettingItem(HugeIcons.strokeRoundedInvoice01, 'Tùy biến mẫu hóa đơn in ấn', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Tính năng tùy biến mẫu hóa đơn sẽ sớm khả dụng ở bản cập nhật kế tiếp!'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }, c),
                _SettingItem(HugeIcons.strokeRoundedCreditCard, 'Thiết lập VietQR & TK nhận tiền', () => context.push('/payment-config'), c),
                _SettingItem(HugeIcons.strokeRoundedTruck, 'Đơn vị vận chuyển đối tác', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Tính năng quản lý vận chuyển đối tác sẽ sớm khả dụng ở bản cập nhật kế tiếp!'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }, c),
              ],
              c,
            ),

            _SettingGroup(
              'Thuế & Nghĩa vụ kê khai',
              [
                _SettingItem(HugeIcons.strokeRoundedCalculator01, 'Cấu hình sắc thuế mặc định', () => context.push('/tax-config'), c),
                _SettingItem(HugeIcons.strokeRoundedCustomerSupport, 'Kênh hỗ trợ giải đáp luật thuế', () => context.push('/tax-support'), c),
              ],
              c,
            ),

            _SettingGroup(
              'Hệ thống & Trợ giúp',
              [
                _SettingItem(HugeIcons.strokeRoundedNotification03, 'Trung tâm quản lý thông báo', () => context.push('/notifications'), c),
                _SettingItem(HugeIcons.strokeRoundedCloudSavingDone01, 'Sao lưu & khôi phục dữ liệu', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Sao lưu và khôi phục dữ liệu sẽ sớm khả dụng ở bản cập nhật kế tiếp!'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }, c),
                _SettingItem(HugeIcons.strokeRoundedHelpCircle, 'Thông tin phần mềm hỗ trợ', () async {
                  final pkg = await PackageInfo.fromPlatform();
                  if (!context.mounted) return;
                  showAboutDialog(
                    context: context,
                    applicationName: 'SmartStock FinTech',
                    applicationVersion: pkg.version,
                    applicationLegalese: '© 2026 SmartStock Inc. Bảo lưu mọi quyền.',
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        'Hệ sinh thái số quản lý bán hàng và hỗ trợ cảnh báo thuế thông minh dành riêng cho hộ kinh doanh cá thể tại Việt Nam.',
                        style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                      ),
                    ],
                  );
                }, c),
              ],
              c,
            ),
            const SizedBox(height: 16),

            // Redundant outlined Log Out button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                icon: HugeIcon(icon: HugeIcons.strokeRoundedLogout03, color: AppColors.danger, size: 20),
                label: Text(
                  'Đăng Xuất Tài Khoản',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.danger),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showShopSwitcher(BuildContext context, WidgetRef ref, ShopState shopState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final c = AppThemeColors.of(ctx);
        final theme = Theme.of(context);
        final primaryColor = theme.colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 44, height: 4, decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(
                'Chuyển đổi cửa hàng liên kết',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(height: 12),
              ...shopState.userShops.map((shop) {
                final isActive = shop['shopId'] == shopState.currentShopId;
                return ListTile(
                  leading: HugeIcon(icon: HugeIcons.strokeRoundedStore01, color: isActive ? primaryColor : c.textMuted, size: 22),
                  title: Text(
                    shop['shopName'] ?? 'Shop #${shop['shopId']}',
                    style: GoogleFonts.outfit(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 14),
                  ),
                  subtitle: Text(
                    shop['memberType'] == 'OWNER' ? 'Chủ sở hữu' : (shop['role']?['name'] ?? 'Nhân viên'),
                    style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary),
                  ),
                  trailing: isActive ? HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: primaryColor, size: 20) : null,
                  onTap: () {
                    ref.read(shopProvider.notifier).switchShop(shop['shopId'] as int);
                    Navigator.pop(ctx);
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: isActive ? primaryColor.withValues(alpha: 0.08) : null,
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _BrandColorTile extends ConsumerWidget {
  final AppThemeColors c;
  const _BrandColorTile({required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandColor = ref.watch(brandColorProvider);
    final isDark = brandColor.isDark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () => _showBrandColorPicker(context, ref, brandColor, c, isDark),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedPaintBoard,
              size: 20,
              color: primaryColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tông màu chủ đạo ứng dụng',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    brandColor.label,
                    style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: brandColor.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: brandColor.color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 18,
              color: c.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _showBrandColorPicker(
    BuildContext context,
    WidgetRef ref,
    AppBrandColor current,
    AppThemeColors c,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Chọn tông màu thương hiệu',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Tùy chỉnh sắc thái giao diện phù hợp với gu thẩm mỹ của bạn',
                style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              // Horizontal list of colors
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: AppBrandColor.values.length,
                  itemBuilder: (context, i) {
                    final item = AppBrandColor.values[i];
                    final isSelected = item == current;
                    return GestureDetector(
                      onTap: () {
                        ref.read(brandColorProvider.notifier).setBrandColor(item);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: item.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : AppColors.primary)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: item.color.withValues(alpha: 0.5),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.label,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Theme.of(context).colorScheme.primary : c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingGroup extends StatelessWidget {
  final String title;
  final List<Widget> items;
  final AppThemeColors c;
  const _SettingGroup(this.title, this.items, this.c);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppThemeColors.of(context).textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppThemeColors.of(context).card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.divider.withValues(alpha: 0.5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: items,
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _SettingItem extends StatelessWidget {
  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  final AppThemeColors c;
  const _SettingItem(this.icon, this.label, this.onTap, this.c);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              HugeIcon(icon: icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CostingMethodTile extends ConsumerStatefulWidget {
  final AppThemeColors c;
  const _CostingMethodTile({required this.c});

  @override
  ConsumerState<_CostingMethodTile> createState() => _CostingMethodTileState();
}

class _CostingMethodTileState extends ConsumerState<_CostingMethodTile> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(costingProvider.notifier).loadCostingMethod());
  }

  @override
  Widget build(BuildContext context) {
    final costing = ref.watch(costingProvider);
    final c = widget.c;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final methodLabel = costing.method == 'FIFO' ? 'Nhập trước - Xuất trước (FIFO)' : 'Bình quân gia quyền (AVG)';

    return _SettingGroup(
      'Phương pháp tính giá vốn',
      [
        InkWell(
          onTap: () => _showCostingMethodPicker(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedCalculator01, size: 20, color: primaryColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Công thức tính giá vốn',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        methodLabel,
                        style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (costing.isLoading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18, color: c.textMuted),
              ],
            ),
          ),
        ),
      ],
      c,
    );
  }

  void _showCostingMethodPicker(BuildContext context) {
    final costing = ref.read(costingProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final c = AppThemeColors.of(ctx);
        final primaryColor = Theme.of(context).colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 44, height: 4, decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(
                'Công thức tính giá vốn hàng bán',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Áp dụng chung làm cơ sở tính lợi nhuận cho toàn bộ sản phẩm',
                style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              _costingOption(
                ctx,
                c,
                'AVG',
                'Bình quân gia quyền liên tục (AVG)',
                'Giá vốn = trung bình giá nhập tất cả các lô còn tồn kho. Phù hợp nhất cho đại đa số hộ kinh doanh.',
                Icons.balance_rounded,
                costing.method == 'AVG',
                primaryColor,
              ),
              const SizedBox(height: 8),
              _costingOption(
                ctx,
                c,
                'FIFO',
                'Nhập trước - Xuất trước (FIFO)',
                'Hàng nhập kho trước sẽ được xuất bán trước. Độ chính xác cao hơn khi biến động giá nhập lớn.',
                Icons.sort_rounded,
                costing.method == 'FIFO',
                primaryColor,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _costingOption(
    BuildContext ctx,
    AppThemeColors c,
    String method,
    String title,
    String desc,
    IconData icon,
    bool isActive,
    Color primaryColor,
  ) {
    return InkWell(
      onTap: () async {
        Navigator.pop(ctx);
        await ref.read(costingProvider.notifier).updateCostingMethod(method);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withValues(alpha: 0.08) : c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? primaryColor : c.divider,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: isActive ? primaryColor : c.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? primaryColor : c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isActive) HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
