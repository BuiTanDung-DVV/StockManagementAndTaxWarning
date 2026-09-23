import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_background_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/avatar_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_avatar.dart';
import 'avatar_picker_dialog.dart';

class ThemeAppearanceModal extends ConsumerStatefulWidget {
  const ThemeAppearanceModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ThemeAppearanceModal(),
    );
  }

  @override
  ConsumerState<ThemeAppearanceModal> createState() =>
      _ThemeAppearanceModalState();
}

class _ThemeAppearanceModalState extends ConsumerState<ThemeAppearanceModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploadingBg = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomBackground() async {
    setState(() => _isUploadingBg = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = base64Encode(bytes);
        await ref
            .read(appBackgroundProvider.notifier)
            .setCustomImage(
              filePath: kIsWeb ? null : picked.path,
              base64Data: base64String,
            );
        ToastService.showSuccess('Đã áp dụng hình nền tùy chỉnh!');
      }
    } catch (e) {
      ToastService.showError('Không thể tải hình nền: $e');
    } finally {
      if (mounted) setState(() => _isUploadingBg = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final themeMode = ref.watch(themeModeSettingProvider);
    final brandColor = ref.watch(brandColorProvider);
    final bgState = ref.watch(appBackgroundProvider);
    final avatarState = ref.watch(userAvatarProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: AppAssetIcon(
                      assetPath: AppAssets.palette,
                      size: 22,
                      color: Theme.of(context).colorScheme.primary,
                      semanticLabel: 'Tùy biến giao diện',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tùy biến giao diện & hình nền',
                          style: GoogleFonts.inter(
                            color: colors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Cá nhân hóa màu sắc, ảnh nền và ảnh đại diện',
                          style: GoogleFonts.inter(
                            color: colors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: AppAssetIcon(
                      assetPath: AppAssets.close,
                      size: 18,
                      color: colors.textSecondary,
                      semanticLabel: 'Đóng',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Mini-Preview of interface
            _LiveMiniPreview(
              themeMode: themeMode,
              brandColor: brandColor,
              bgState: bgState,
            ),
            const SizedBox(height: 12),

            // Tabs strictly with AppAssets
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.cardAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.divider),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: colors.textSecondary,
                labelStyle: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(
                    icon: AppAssetIcon(
                      assetPath: AppAssets.palette,
                      size: 16,
                      semanticLabel: 'Màu sắc',
                    ),
                    text: 'Màu sắc & Chế độ',
                  ),
                  Tab(
                    icon: AppAssetIcon(
                      assetPath: AppAssets.wallpaper,
                      size: 16,
                      semanticLabel: 'Hình nền',
                    ),
                    text: 'Hình nền App',
                  ),
                  Tab(
                    icon: AppAssetIcon(
                      assetPath: AppAssets.avatar,
                      size: 16,
                      semanticLabel: 'Avatar',
                    ),
                    text: 'Ảnh đại diện',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Theme Mode & Brand Color
                  _buildThemeAndColorTab(
                    context,
                    colors,
                    themeMode,
                    brandColor,
                  ),

                  // Tab 2: Wallpaper / Background
                  _buildWallpaperTab(context, colors, bgState),

                  // Tab 3: Avatar System
                  _buildAvatarTab(context, colors, avatarState),
                ],
              ),
            ),

            // Bottom Actions
            Divider(height: 1, color: colors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ref
                          .read(themeModeSettingProvider.notifier)
                          .setThemeMode(AppThemeModeSetting.light);
                      ref
                          .read(brandColorProvider.notifier)
                          .setBrandColor(AppBrandColor.tealSmartStock);
                      ref.read(appBackgroundProvider.notifier).resetDefault();
                      ref.read(userAvatarProvider.notifier).resetDefault();
                      ToastService.showInfo(
                        'Đã đặt lại toàn bộ cài đặt mặc định',
                      );
                    },
                    icon: AppAssetIcon(
                      assetPath: AppAssets.refresh,
                      size: 15,
                      color: colors.textSecondary,
                      semanticLabel: 'Khôi phục mặc định',
                    ),
                    label: Text(
                      'Khôi phục chuẩn',
                      style: GoogleFonts.inter(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Hoàn tất',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeAndColorTab(
    BuildContext context,
    AppThemeColors colors,
    AppThemeModeSetting currentMode,
    AppBrandColor currentBrand,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Text(
          'CHẾ ĐỘ HIỂN THỊ',
          style: GoogleFonts.inter(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildThemeModeCard(
              context: context,
              colors: colors,
              title: 'Sáng',
              subtitle: 'Tiêu chuẩn',
              assetPath: AppAssets.sun,
              isSelected: currentMode == AppThemeModeSetting.light,
              onTap: () {
                ref
                    .read(themeModeSettingProvider.notifier)
                    .setThemeMode(AppThemeModeSetting.light);
              },
            ),
            const SizedBox(width: 10),
            _buildThemeModeCard(
              context: context,
              colors: colors,
              title: 'Tối',
              subtitle: 'Bảo vệ mắt',
              assetPath: AppAssets.moon,
              isSelected: currentMode == AppThemeModeSetting.dark,
              onTap: () {
                ref
                    .read(themeModeSettingProvider.notifier)
                    .setThemeMode(AppThemeModeSetting.dark);
              },
            ),
            const SizedBox(width: 10),
            _buildThemeModeCard(
              context: context,
              colors: colors,
              title: 'Tự động',
              subtitle: 'Theo thiết bị',
              assetPath: AppAssets.systemMode,
              isSelected: currentMode == AppThemeModeSetting.system,
              onTap: () {
                ref
                    .read(themeModeSettingProvider.notifier)
                    .setThemeMode(AppThemeModeSetting.system);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'BẢNG MÀU THƯƠNG HIỆU (BRAND ACCENT)',
          style: GoogleFonts.inter(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.8,
          ),
          itemCount: AppBrandColor.values.length,
          itemBuilder: (context, index) {
            final item = AppBrandColor.values[index];
            final isSelected = item == currentBrand;

            return InkWell(
              onTap: () {
                ref.read(brandColorProvider.notifier).setBrandColor(item);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? item.color.withValues(alpha: 0.08)
                      : colors.cardAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? item.color : colors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: isSelected
                          ? const AppAssetIcon(
                              assetPath: AppAssets.check,
                              size: 14,
                              color: Colors.white,
                              semanticLabel: 'Đã chọn',
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: colors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          Text(
                            item.isDark ? 'Giao diện tối' : 'Màu điểm nhấn',
                            style: GoogleFonts.inter(
                              color: colors.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildThemeModeCard({
    required BuildContext context,
    required AppThemeColors colors,
    required String title,
    required String subtitle,
    required String assetPath,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: 0.08)
                : colors.cardAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? primary : colors.divider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              AppAssetIcon(
                assetPath: assetPath,
                size: 24,
                color: isSelected ? primary : colors.textSecondary,
                semanticLabel: title,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: isSelected ? primary : colors.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: colors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWallpaperTab(
    BuildContext context,
    AppThemeColors colors,
    AppBackgroundState bgState,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'HOA VĂN & HÌNH NỀN ỨNG DỤNG',
              style: GoogleFonts.inter(
                color: colors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isUploadingBg ? null : _pickCustomBackground,
              icon: AppAssetIcon(
                assetPath: AppAssets.upload,
                size: 15,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: 'Tải ảnh nền',
              ),
              label: Text(
                _isUploadingBg ? 'Đang tải...' : 'Tải ảnh từ máy',
                style: GoogleFonts.inter(fontSize: 11.5),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.primarySubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primaryBorder, width: 1),
          ),
          child: Row(
            children: [
              AppAssetIcon(
                assetPath: AppAssets.check,
                size: 16,
                color: colors.primary,
                semanticLabel: 'Tối ưu tự động',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Độ tương phản và độ mờ được tự động tối ưu hóa (chuẩn WCAG AAA), đảm bảo số liệu và hóa đơn luôn sắc nét, dễ đọc.',
                  style: GoogleFonts.inter(
                    color: colors.textPrimary,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Wallpaper Presets Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
          ),
          itemCount: AppWallpaperPreset.values.length,
          itemBuilder: (context, index) {
            final preset = AppWallpaperPreset.values[index];
            final isSelected = !bgState.isCustom && bgState.preset == preset;

            return InkWell(
              onTap: () {
                ref.read(appBackgroundProvider.notifier).setPreset(preset);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.cardAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : colors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    if (preset != AppWallpaperPreset.none &&
                        preset.assetPath.isNotEmpty)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Opacity(
                            opacity: 0.25,
                            child: AppAssetIcon(
                              assetPath: preset.assetPath,
                              fit: BoxFit.cover,
                              semanticLabel: preset.label,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: colors.card,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.divider),
                                ),
                                alignment: Alignment.center,
                                child: AppAssetIcon(
                                  assetPath: AppAssets.wallpaper,
                                  size: 13,
                                  color: Theme.of(context).colorScheme.primary,
                                  semanticLabel: 'Hình nền',
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const AppAssetIcon(
                                    assetPath: AppAssets.check,
                                    size: 11,
                                    color: Colors.white,
                                    semanticLabel: 'Đã chọn',
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            preset.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: colors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          Text(
                            preset.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: colors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvatarTab(
    BuildContext context,
    AppThemeColors colors,
    UserAvatarState avatarState,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cardAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            children: [
              const AppAvatar(
                size: 64,
                borderWidth: 2,
                borderColor: Color(0xFF2563EB),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avatarState.hasCustomImage
                          ? 'Ảnh cá nhân đã tải'
                          : (avatarState.preset?.label ?? 'Mẫu avatar'),
                      style: GoogleFonts.inter(
                        color: colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      avatarState.hasCustomImage
                          ? 'Ảnh từ tệp thiết bị'
                          : 'Bộ nhận diện: ${avatarState.preset?.category ?? "Hệ thống"}',
                      style: GoogleFonts.inter(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => AvatarPickerDialog.show(context),
                icon: AppAssetIcon(
                  assetPath: AppAssets.avatar,
                  size: 15,
                  color: Colors.white,
                  semanticLabel: 'Đổi ảnh',
                ),
                label: Text('Chọn mẫu', style: GoogleFonts.inter(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'CHỌN NHANH AVATAR NHẬN DIỆN',
          style: GoogleFonts.inter(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final preset in AppAvatarPreset.values)
              InkWell(
                onTap: () {
                  ref.read(userAvatarProvider.notifier).setPreset(preset);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:
                        !avatarState.hasCustomImage &&
                            avatarState.preset == preset
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.08)
                        : colors.cardAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          !avatarState.hasCustomImage &&
                              avatarState.preset == preset
                          ? Theme.of(context).colorScheme.primary
                          : colors.divider,
                      width:
                          !avatarState.hasCustomImage &&
                              avatarState.preset == preset
                          ? 2
                          : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      AppAvatar(size: 42, assetPath: preset.assetPath),
                      const SizedBox(height: 4),
                      Text(
                        preset.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LiveMiniPreview extends StatelessWidget {
  final AppThemeModeSetting themeMode;
  final AppBrandColor brandColor;
  final AppBackgroundState bgState;

  const _LiveMiniPreview({
    required this.themeMode,
    required this.brandColor,
    required this.bgState,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        themeMode == AppThemeModeSetting.dark ||
        (themeMode == AppThemeModeSetting.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final primary = brandColor.color;
    final bgColor = isDark ? const Color(0xFF0B1420) : const Color(0xFFF5F8F7);
    final surfaceColor = isDark
        ? const Color(0xFF111D2B)
        : const Color(0xFFFFFFFF);
    final cardColor = isDark
        ? const Color(0xFF172536)
        : const Color(0xFFFFFFFF);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF17332F);
    final textMuted = isDark
        ? const Color(0xFF91A3B8)
        : const Color(0xFF5D716B);
    final dividerColor = isDark
        ? const Color(0xFF2A3C50)
        : const Color(0xFFDCE7E3);

    final opacity = bgState.getEffectiveOpacity(isDark);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 120,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bgState.hasBackground)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: (opacity * 1.8).clamp(0.06, 0.30),
                  child:
                      bgState.preset != AppWallpaperPreset.none &&
                          bgState.preset.assetPath.isNotEmpty
                      ? (bgState.preset.assetPath.endsWith('.svg')
                            ? SvgPicture.asset(
                                bgState.preset.assetPath,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                bgState.preset.assetPath,
                                fit: BoxFit.cover,
                              ))
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          Row(
            children: [
              // Mini Sidebar
              Container(
                width: 66,
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primary.withValues(alpha: 0.22),
                            primary.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'SmartStock',
                        style: GoogleFonts.inter(
                          color: primary,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(4),
                        border: Border(
                          left: BorderSide(color: primary, width: 2.5),
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    for (int i = 0; i < 2; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF172536)
                                : const Color(0xFFEDF4F1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Container(width: 1, color: dividerColor),

              // Mini Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: dividerColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Cửa hàng chính',
                                  style: GoogleFonts.inter(
                                    color: textPrimary,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Live Preview',
                              style: GoogleFonts.inter(
                                color: primary,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: primary.withValues(alpha: 0.22),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Doanh thu tháng',
                                      style: GoogleFonts.inter(
                                        color: textMuted,
                                        fontSize: 7.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '128.5M ₫',
                                          style: GoogleFonts.inter(
                                            color: textPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF10B981,
                                            ).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '+14%',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF10B981),
                                              fontSize: 7.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Tạo đơn',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
