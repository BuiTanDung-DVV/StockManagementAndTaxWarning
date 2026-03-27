import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/system_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/notification_provider.dart';
import 'staff_management_screen.dart';
import 'notification_list_screen.dart';
import 'profile_screen.dart';
import '../providers/costing_provider.dart';
import '../../../core/guides/feature_guide_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final shopAsync = ref.watch(shopProfileProvider);
    final themeMode = ref.watch(themeProvider);
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
            IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationListScreen()))),
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
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: shopAsync.when(
            data: (shop) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    ((auth.user?['fullName'] as String?)?.isNotEmpty == true ? (auth.user!['fullName'] as String)[0] : '?').toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(auth.user?['fullName'] ?? 'Người dùng', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(shop['shopName'] ?? shop['name'] ?? 'Cửa hàng', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  Text('MST: ${shop['taxCode'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ])),
                Icon(Icons.chevron_right, color: c.textMuted, size: 22),
              ]),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    ((auth.user?['fullName'] as String?)?.isNotEmpty == true ? (auth.user!['fullName'] as String)[0] : '?').toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(auth.user?['fullName'] ?? 'Người dùng', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Nhấn để xem thông tin cá nhân', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ])),
                Icon(Icons.chevron_right, color: c.textMuted, size: 22),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Shop switcher (if user has multiple shops) ──
        if (shopState.userShops.length > 1)
          _SettingGroup('Cửa hàng hiện tại', [
            _SettingItem(Icons.swap_horiz, 'Chuyển shop (${shopState.currentShopName ?? ""})', () {
              _showShopSwitcher(context, ref, shopState);
            }, c),
          ], c),

        // ── Appearance / Theme toggle ──
        _SettingGroup('Giao diện', [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.palette, size: 20, color: AppColors.primary),
              const SizedBox(width: 14),
              const Expanded(child: Text('Chế độ hiển thị', style: TextStyle(fontSize: 14))),
              _ThemeSelector(current: themeMode, onChanged: (m) => ref.read(themeProvider.notifier).setTheme(m)),
            ]),
          ),
        ], c),

        // ── Staff management (only for shop owners) ──
        if (shopState.isOwner || auth.isShopOwner)
          _SettingGroup('Nhân viên & Phân quyền', [
            _SettingItem(Icons.people, 'Quản lý nhân viên', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen())), c),
            _SettingItem(Icons.admin_panel_settings, 'Quản lý vai trò', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleConfigScreen())), c),
          ], c),

        _SettingGroup('Quản lý', [
          _SettingItem(Icons.category, 'Danh mục SP', () {}, c),
          _SettingItem(Icons.warehouse, 'Kho hàng', () {}, c),
          _SettingItem(Icons.history, 'Nhật ký hoạt động', () => context.go('/activity-logs'), c),
        ], c),
        _CostingMethodTile(c: c),
        _SettingGroup('Cửa hàng', [
          _SettingItem(Icons.receipt, 'Mẫu hóa đơn', () {}, c),
          _SettingItem(Icons.payments, 'Phương thức TT', () => context.go('/payment-config'), c),
          _SettingItem(Icons.local_shipping, 'Đơn vị vận chuyển', () {}, c),
        ], c),
        _SettingGroup('Thuế & Kê khai', [
          _SettingItem(Icons.calculate, 'Cấu hình thuế', () => context.go('/tax-config'), c),
          _SettingItem(Icons.support_agent, 'Hỗ trợ thuế', () => context.go('/tax-support'), c),
        ], c),
        _SettingGroup('Hệ thống', [
          _SettingItem(Icons.notifications, 'Thông báo', () {}, c),
          _SettingItem(Icons.backup, 'Sao lưu dữ liệu', () {}, c),
          _SettingItem(Icons.help, 'Trợ giúp', () {}, c),
        ], c),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout, color: AppColors.danger),
          label: Text('Đăng xuất', style: TextStyle(color: AppColors.danger)),
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
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Chuyển cửa hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...shopState.userShops.map((shop) {
              final isActive = shop['shopId'] == shopState.currentShopId;
              return ListTile(
                leading: Icon(Icons.storefront, color: isActive ? AppColors.primary : c.textMuted),
                title: Text(shop['shopName'] ?? 'Shop #${shop['shopId']}', style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(shop['memberType'] == 'OWNER' ? 'Chủ shop' : (shop['role']?['name'] ?? 'Nhân viên'), style: TextStyle(fontSize: 12, color: c.textSecondary)),
                trailing: isActive ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                onTap: () {
                  ref.read(shopProvider.notifier).switchShop(shop['shopId'] as int);
                  Navigator.pop(ctx);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: isActive ? AppColors.primary.withValues(alpha: 0.08) : null,
              );
            }),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }
}

// ── Theme Selector Widget ──────────────────────────

class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _chip(context, Icons.light_mode, 'Sáng', ThemeMode.light),
        _chip(context, Icons.dark_mode, 'Tối', ThemeMode.dark),
      ]),
    );
  }

  Widget _chip(BuildContext ctx, IconData icon, String label, ThemeMode mode) {
    final active = current == mode;
    return GestureDetector(
      onTap: () => onChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? AppColors.primary : AppThemeColors.of(ctx).textMuted),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? AppColors.primary : AppThemeColors.of(ctx).textMuted)),
        ]),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────

class _SettingGroup extends StatelessWidget {
  final String title; final List<Widget> items; final AppThemeColors c;
  const _SettingGroup(this.title, this.items, this.c);
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: EdgeInsets.only(bottom: 8), child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppThemeColors.of(context).textSecondary))),
    Container(decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)), child: Column(children: items)),
    const SizedBox(height: 16),
  ]);
}

class _SettingItem extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final AppThemeColors c;
  const _SettingItem(this.icon, this.label, this.onTap, this.c);
  @override Widget build(BuildContext context) => InkWell(onTap: onTap,
    child: Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [Icon(icon, size: 20, color: AppColors.primary), SizedBox(width: 14), Expanded(child: Text(label, style: TextStyle(fontSize: 14))), Icon(Icons.chevron_right, size: 18, color: AppThemeColors.of(context).textMuted)])));
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
    final methodLabel = costing.method == 'FIFO' ? 'Nhập trước - Xuất trước (FIFO)' : 'Bình quân gia quyền (AVG)';

    return _SettingGroup('Giá vốn hàng bán', [
      InkWell(
        onTap: () => _showCostingMethodPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            const Icon(Icons.calculate_outlined, size: 20, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Phương pháp tính giá vốn', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 2),
              Text(methodLabel, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ])),
            if (costing.isLoading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.chevron_right, size: 18, color: c.textMuted),
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
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Chọn phương pháp tính giá vốn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Áp dụng cho tất cả sản phẩm', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(height: 16),
            _costingOption(ctx, c, 'AVG', 'Bình quân gia quyền (AVG)',
                'Giá vốn = trung bình giá nhập tất cả các lô còn tồn. Đơn giản, phù hợp SME.',
                Icons.balance, costing.method == 'AVG'),
            const SizedBox(height: 8),
            _costingOption(ctx, c, 'FIFO', 'Nhập trước - Xuất trước (FIFO)',
                'Hàng nhập trước sẽ xuất trước. Chính xác hơn khi giá nhập biến động nhiều.',
                Icons.sort, costing.method == 'FIFO'),
            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }

  Widget _costingOption(BuildContext ctx, AppThemeColors c, String method, String title, String desc, IconData icon, bool isActive) {
    return InkWell(
      onTap: () async {
        Navigator.pop(ctx);
        await ref.read(costingProvider.notifier).updateCostingMethod(method);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.08) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? AppColors.primary : c.textMuted.withValues(alpha: 0.2), width: isActive ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 24, color: isActive ? AppColors.primary : c.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isActive ? AppColors.primary : null)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ])),
          if (isActive) const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
        ]),
      ),
    );
  }
}

