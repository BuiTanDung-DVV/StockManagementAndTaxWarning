import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/system_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/costing_provider.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import 'package:hugeicons/hugeicons.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final shopAsync = ref.watch(shopProfileProvider);
    final shopState = ref.watch(shopProvider);
    final auth = ref.watch(authProvider);
    final notifState = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        actions: [
          featureGuideButton(context, 'settings'),
          // Notification bell
          Stack(children: [
            IconButton(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedNotification03, color: c.textSecondary, size: 22),
              onPressed: () => context.push('/notifications'),
            ),
            if (notifState.unreadCount > 0)
              Positioned(right: 6, top: 6, child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                child: Text('${notifState.unreadCount}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
              )),
          ]),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        // Profile card - tappable
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: shopAsync.when(
            data: (shop) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    ((auth.user?['fullName'] as String?)?.isNotEmpty == true ? (auth.user!['fullName'] as String)[0] : '?').toUpperCase(),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(auth.user?['fullName'] ?? 'Người dùng', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(shop['shopName'] ?? shop['name'] ?? 'Cửa hàng', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  Text('MST: ${shop['taxCode'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  if (shopState.isOwner && shopState.shopCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text('Mã CH: ${shopState.shopCode}', style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                ])),
                HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: c.textMuted, size: 22),
              ]),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    ((auth.user?['fullName'] as String?)?.isNotEmpty == true ? (auth.user!['fullName'] as String)[0] : '?').toUpperCase(),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(auth.user?['fullName'] ?? 'Người dùng', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Nhấn để xem thông tin cá nhân', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ])),
                HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: c.textMuted, size: 22),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Shop switcher (if user has multiple shops) ──
        if (shopState.userShops.length > 1)
          _SettingGroup('Cửa hàng hiện tại', [
            _SettingItem(HugeIcons.strokeRoundedExchange01, 'Chuyển shop (${shopState.currentShopName ?? ""})', () {
              _showShopSwitcher(context, ref, shopState);
            }, c),
          ], c),

        // ── Appearance / Theme toggle ──
        _SettingGroup('Giao diện', [
          _BrandColorTile(c: c),
        ], c),

        // ── Staff management (only for shop owners) ──
        if (shopState.isOwner || auth.isShopOwner)
          _SettingGroup('Nhân viên & Phân quyền', [
            _SettingItem(HugeIcons.strokeRoundedUserMultiple, 'Quản lý nhân viên', () => context.push('/staff'), c),
            _SettingItem(HugeIcons.strokeRoundedUserStar02, 'Quản lý vai trò', () => context.push('/roles'), c),
          ], c),

        _SettingGroup('Quản lý', [
          _SettingItem(HugeIcons.strokeRoundedDashboardSquare01, 'Danh mục SP', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quản lý danh mục sẽ sớm khả dụng'), duration: Duration(seconds: 2)));
          }, c),
          _SettingItem(HugeIcons.strokeRoundedClock04, 'Nhật ký hoạt động', () => context.push('/activity-logs'), c),
        ], c),
        _CostingMethodTile(c: c),
        _SettingGroup('Cửa hàng', [
          _SettingItem(HugeIcons.strokeRoundedStore01, 'Thông tin cửa hàng', () => context.push('/shop-profile'), c),
          _SettingItem(HugeIcons.strokeRoundedInvoice01, 'Mẫu hóa đơn', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tùy chỉnh mẫu hóa đơn sẽ sớm khả dụng'), duration: Duration(seconds: 2)));
          }, c),
          _SettingItem(HugeIcons.strokeRoundedCreditCard, 'Phương thức TT', () => context.push('/payment-config'), c),
          _SettingItem(HugeIcons.strokeRoundedTruck, 'Đơn vị vận chuyển', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quản lý vận chuyển sẽ sớm khả dụng'), duration: Duration(seconds: 2)));
          }, c),
        ], c),
        _SettingGroup('Thuế & Kê khai', [
          _SettingItem(HugeIcons.strokeRoundedCalculator01, 'Cấu hình thuế', () => context.push('/tax-config'), c),
          _SettingItem(HugeIcons.strokeRoundedCustomerSupport, 'Hỗ trợ thuế', () => context.push('/tax-support'), c),
        ], c),
        _SettingGroup('Hệ thống', [
          _SettingItem(HugeIcons.strokeRoundedNotification03, 'Thông báo', () => context.push('/notifications'), c),
          _SettingItem(HugeIcons.strokeRoundedCloudSavingDone01, 'Sao lưu dữ liệu', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sao lưu & khôi phục sẽ sớm khả dụng'), duration: Duration(seconds: 2)));
          }, c),
          _SettingItem(HugeIcons.strokeRoundedHelpCircle, 'Trợ giúp', () async {
            final pkg = await PackageInfo.fromPlatform();
            if (!context.mounted) return;
            showAboutDialog(
              context: context,
              applicationName: 'Sales & Stock Management',
              applicationVersion: pkg.version,
              applicationLegalese: '© 2026 All rights reserved',
              children: [const SizedBox(height: 12), const Text('Ứng dụng quản lý bán hàng và kho hàng dành cho hộ kinh doanh.', style: TextStyle(fontSize: 13))],
            );
          }, c),
        ], c),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
          icon: HugeIcon(icon: HugeIcons.strokeRoundedLogout03, color: AppColors.danger, size: 20),
          label: const Text('Đăng xuất', style: TextStyle(color: AppColors.danger)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger), padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
      ])),
    );
  }

  void _showShopSwitcher(BuildContext context, WidgetRef ref, ShopState shopState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final c = AppThemeColors.of(ctx);
        final primaryColor = Theme.of(context).colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Chuyển cửa hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...shopState.userShops.map((shop) {
              final isActive = shop['shopId'] == shopState.currentShopId;
              return ListTile(
                leading: HugeIcon(icon: HugeIcons.strokeRoundedStore01, color: isActive ? primaryColor : c.textMuted, size: 24),
                title: Text(shop['shopName'] ?? 'Shop #${shop['shopId']}', style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(shop['memberType'] == 'OWNER' ? 'Chủ shop' : (shop['role']?['name'] ?? 'Nhân viên'), style: TextStyle(fontSize: 12, color: c.textSecondary)),
                trailing: isActive ? HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: primaryColor, size: 22) : null,
                onTap: () {
                  ref.read(shopProvider.notifier).switchShop(shop['shopId'] as int);
                  Navigator.pop(ctx);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: isActive ? primaryColor.withValues(alpha: 0.08) : null,
              );
            }),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }
}

// ── Brand Color Tile Widget ────────────────────────

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
        child: Row(children: [
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
                const Text('Màu sắc chủ đạo', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  brandColor.label,
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
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
          const SizedBox(width: 8),
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            size: 18,
            color: c.textMuted,
          ),
        ]),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn màu sắc ứng dụng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Tùy chỉnh tông màu chủ đạo phù hợp với thương hiệu',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
              const SizedBox(height: 20),
              // Horizontal list of colors
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
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
                                      Icons.check,
                                      color: Colors.white,
                                      size: 24,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : c.textSecondary,
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

// ── Helper widgets ─────────────────────────────────

class _SettingGroup extends StatelessWidget {
  final String title; final List<Widget> items; final AppThemeColors c;
  const _SettingGroup(this.title, this.items, this.c);
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppThemeColors.of(context).textSecondary))),
    Container(decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)), child: Column(children: items)),
    const SizedBox(height: 16),
  ]);
}

class _SettingItem extends StatelessWidget {
  final dynamic icon; final String label; final VoidCallback onTap; final AppThemeColors c;
  const _SettingItem(this.icon, this.label, this.onTap, this.c);
  @override Widget build(BuildContext context) => InkWell(onTap: onTap,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [HugeIcon(icon: icon, size: 20, color: Theme.of(context).colorScheme.primary), SizedBox(width: 14), Expanded(child: Text(label, style: TextStyle(fontSize: 14))), HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18, color: AppThemeColors.of(context).textMuted)])));
}

// ── Costing Method Tile ────────────────────────────

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

    return _SettingGroup('Giá vốn hàng bán', [
      InkWell(
        onTap: () => _showCostingMethodPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            HugeIcon(icon: HugeIcons.strokeRoundedCalculator01, size: 20, color: primaryColor),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Phương pháp tính giá vốn', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 2),
              Text(methodLabel, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ])),
            if (costing.isLoading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18, color: c.textMuted),
          ]),
        ),
      ),
    ], c);
  }

  void _showCostingMethodPicker(BuildContext context) {
    final costing = ref.read(costingProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final c = AppThemeColors.of(ctx);
        final primaryColor = Theme.of(context).colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Chọn phương pháp tính giá vốn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Áp dụng cho tất cả sản phẩm', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(height: 16),
            _costingOption(ctx, c, 'AVG', 'Bình quân gia quyền (AVG)',
                'Giá vốn = trung bình giá nhập tất cả các lô còn tồn. Đơn giản, phù hợp SME.',
                Icons.balance, costing.method == 'AVG', primaryColor),
            const SizedBox(height: 8),
            _costingOption(ctx, c, 'FIFO', 'Nhập trước - Xuất trước (FIFO)',
                'Hàng nhập trước sẽ xuất trước. Chính xác hơn khi giá nhập biến động nhiều.',
                Icons.sort, costing.method == 'FIFO', primaryColor),
            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }

  Widget _costingOption(BuildContext ctx, AppThemeColors c, String method, String title, String desc, IconData icon, bool isActive, Color primaryColor) {
    return InkWell(
      onTap: () async {
        Navigator.pop(ctx);
        await ref.read(costingProvider.notifier).updateCostingMethod(method);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withValues(alpha: 0.08) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? primaryColor : c.textMuted.withValues(alpha: 0.2), width: isActive ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 24, color: isActive ? primaryColor : c.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isActive ? primaryColor : null)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ])),
          if (isActive) HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: primaryColor, size: 22),
        ]),
      ),
    );
  }
}

