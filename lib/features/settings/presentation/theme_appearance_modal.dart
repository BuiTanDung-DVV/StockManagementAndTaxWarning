import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/localization/app_localizations.dart';
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
                      semanticLabel: context.tr.settings.appearanceAndWallpaper,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr.settings.appearanceModalTitle,
                          style: GoogleFonts.inter(
                            color: colors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          context.tr.settings.appearanceModalSubtitle,
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
                      semanticLabel: context.tr.common.close,
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
                tabs: [
                  Tab(
                    icon: AppAssetIcon(
                      assetPath: AppAssets.palette,
                      size: 16,
                      semanticLabel: context.tr.settings.tabColorAndMode,
                    ),
                    text: context.tr.settings.tabColorAndMode,
                  ),
                  Tab(
                    icon: AppAssetIcon(
                      assetPath: AppAssets.wallpaper,
                      size: 16,
                      semanticLabel: context.tr.settings.tabWallpaper,
                    ),
                    text: context.tr.settings.tabWallpaper,
                  ),
                  Tab(
                    icon: AppAssetIcon(
                      assetPath: AppAssets.avatar,
                      size: 16,
                      semanticLabel: context.tr.settings.tabAvatar,
                    ),
                    text: context.tr.settings.tabAvatar,
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
                        context.isEnglish
                            ? 'All appearance settings reset to default'
                            : 'Đã đặt lại toàn bộ cài đặt mặc định',
                      );
                    },
                    icon: AppAssetIcon(
                      assetPath: AppAssets.refresh,
                      size: 15,
                      color: colors.textSecondary,
                      semanticLabel: context.tr.settings.resetDefaults,
                    ),
                    label: Text(
                      context.tr.settings.resetDefaults,
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
                      context.tr.settings.finish,
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
          context.tr.settings.displayModeTitle,
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
              title: AppThemeModeSetting.light.localizedLabel(
                context.isEnglish,
              ),
              subtitle: context.isEnglish ? 'Standard' : 'Tiêu chuẩn',
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
              title: AppThemeModeSetting.dark.localizedLabel(context.isEnglish),
              subtitle: context.isEnglish ? 'Eye care' : 'Bảo vệ mắt',
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
              title: AppThemeModeSetting.system.localizedLabel(
                context.isEnglish,
              ),
              subtitle: context.isEnglish ? 'Device auto' : 'Theo thiết bị',
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
          context.tr.settings.brandColorTitle,
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
                            item.localizedLabel(context.isEnglish),
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
                            item.isDark
                                ? (context.isEnglish
                                      ? 'Dark theme'
                                      : 'Giao diện tối')
                                : (context.isEnglish
                                      ? 'Accent color'
                                      : 'Màu điểm nhấn'),
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
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr.settings.wallpaperTitle,
              style: GoogleFonts.inter(
                color: colors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (bgState.hasCustomImage)
              TextButton.icon(
                onPressed: _isUploadingBg ? null : _pickCustomBackground,
                icon: AppAssetIcon(
                  assetPath: AppAssets.upload,
                  size: 13,
                  color: primary,
                  semanticLabel: context.tr.settings.changeImage,
                ),
                label: Text(
                  _isUploadingBg
                      ? (context.isEnglish ? 'Uploading...' : 'Đang nạp...')
                      : context.tr.settings.changeImage,
                  style: GoogleFonts.inter(
                    color: primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
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
                semanticLabel: context.tr.common.info,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr.settings.wallpaperNotice,
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

        // GridView hiển thị 1 Card Ảnh Tùy Chỉnh + 6 Card Preset
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 520;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isWide ? 2 : 1,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: isWide ? 1.48 : 2.1,
              children: [
                // 1. Mặc định (Không nền)
                _buildPresetCard(
                  context: context,
                  colors: colors,
                  preset: AppWallpaperPreset.none,
                  isSelected:
                      !bgState.isCustom &&
                      bgState.preset == AppWallpaperPreset.none,
                ),

                // 2. Card chuyên dụng cho Ảnh tùy chỉnh (Lưu trên máy người dùng, chỉ 1 card duy nhất)
                _buildCustomWallpaperCard(
                  context: context,
                  colors: colors,
                  bgState: bgState,
                ),

                // 3..7. Các Wallpaper Presets đặc trưng
                for (final preset in AppWallpaperPreset.values.where(
                  (p) => p != AppWallpaperPreset.none,
                ))
                  _buildPresetCard(
                    context: context,
                    colors: colors,
                    preset: preset,
                    isSelected: !bgState.isCustom && bgState.preset == preset,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Card chuyên dụng cho Ảnh Tùy Chỉnh từ máy tính/thiết bị người dùng.
  /// Lưu cục bộ qua SharedPreferences, không gửi lên DB.
  Widget _buildCustomWallpaperCard({
    required BuildContext context,
    required AppThemeColors colors,
    required AppBackgroundState bgState,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final isSelected = bgState.isCustom;
    final hasImage = bgState.hasCustomImage;

    return InkWell(
      onTap: () {
        if (!hasImage) {
          _pickCustomBackground();
        } else {
          ref.read(appBackgroundProvider.notifier).selectCustomImage();
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.cardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? primary
                : (hasImage ? colors.divider : primary.withValues(alpha: 0.35)),
            width: isSelected ? 2.5 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail Area
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!hasImage)
                      // Slot rỗng: Tải ảnh từ máy
                      Container(
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colors.primarySubtle,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: AppAssetIcon(
                                assetPath: AppAssets.upload,
                                size: 18,
                                color: primary,
                                semanticLabel:
                                    context.tr.settings.uploadFromDevice,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isUploadingBg
                                  ? (context.isEnglish
                                        ? 'Uploading...'
                                        : 'Đang nạp ảnh...')
                                  : context.tr.settings.uploadFromDevice,
                              style: GoogleFonts.inter(
                                color: primary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.isEnglish
                                  ? 'Stored locally on device'
                                  : 'Lưu cục bộ trên thiết bị',
                              style: GoogleFonts.inter(
                                color: colors.textSecondary,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // Đã có ảnh: Hiển thị thumbnail thật của ảnh
                      _buildCustomImageThumbnail(bgState),

                    // Thanh tác vụ trên ảnh: Nút Đổi ảnh & Gỡ ảnh
                    if (hasImage)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Nút Đổi ảnh
                            InkWell(
                              onTap: _isUploadingBg
                                  ? null
                                  : _pickCustomBackground,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppAssetIcon(
                                      assetPath: AppAssets.upload,
                                      size: 11,
                                      color: Colors.white,
                                      semanticLabel:
                                          context.tr.settings.changeImage,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.tr.settings.changeImage,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            // Nút Gỡ ảnh
                            InkWell(
                              onTap: () {
                                ref
                                    .read(appBackgroundProvider.notifier)
                                    .removeCustomImage();
                                ToastService.showInfo(
                                  context.isEnglish
                                      ? 'Custom image removed from device.'
                                      : 'Đã gỡ ảnh tùy chỉnh khỏi máy.',
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: AppAssetIcon(
                                  assetPath: AppAssets.close,
                                  size: 10,
                                  color: Colors.white,
                                  semanticLabel:
                                      context.tr.settings.removeCustomImage,
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
            const SizedBox(height: 8),

            // Nhãn và Trạng thái chọn
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasImage
                            ? context.tr.settings.customWallpaperTitle
                            : context.tr.settings.customWallpaperEmptyTitle,
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
                      const SizedBox(height: 1),
                      Text(
                        hasImage
                            ? context.tr.settings.customWallpaperSubtitle
                            : (context.isEnglish
                                  ? 'Not stored on database'
                                  : 'Không lưu trên database'),
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
                if (isSelected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const AppAssetIcon(
                      assetPath: AppAssets.check,
                      size: 12,
                      color: Colors.white,
                      semanticLabel: 'Đã chọn',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Hiển thị thumbnail ảnh thật của người dùng đã tải
  Widget _buildCustomImageThumbnail(AppBackgroundState bgState) {
    if (bgState.customBase64 != null && bgState.customBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(bgState.customBase64!);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } catch (_) {}
    }
    if (bgState.customImagePath != null && !kIsWeb) {
      try {
        final file = File(bgState.customImagePath!);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        }
      } catch (_) {}
    }
    return Container(
      color: const Color(0xFF334155),
      alignment: Alignment.center,
      child: const AppAssetIcon(
        assetPath: AppAssets.image,
        size: 26,
        color: Colors.white70,
        semanticLabel: 'Ảnh',
      ),
    );
  }

  /// Card cho từng Preset hình nền có sẵn, với Thumbnail sắc nét, tương phản cao, phân biệt rõ rệt
  Widget _buildPresetCard({
    required BuildContext context,
    required AppThemeColors colors,
    required AppWallpaperPreset preset,
    required bool isSelected,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () {
        ref.read(appBackgroundProvider.notifier).setPreset(preset);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.cardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primary : colors.divider,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail Preview Visual (Sắc nét 100%, không bị mờ 0.25)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildPresetThumbnailVisual(preset, colors),
              ),
            ),
            const SizedBox(height: 8),

            // Tiêu đề & Mô tả
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        preset.localizedLabel(context.isEnglish),
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
                      const SizedBox(height: 1),
                      Text(
                        preset.localizedDescription(context.isEnglish),
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
                if (isSelected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const AppAssetIcon(
                      assetPath: AppAssets.check,
                      size: 12,
                      color: Colors.white,
                      semanticLabel: 'Đã chọn',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Đồ họa Thumbnail trực quan, phong cách riêng biệt, rực rỡ và dễ nhận diện
  Widget _buildPresetThumbnailVisual(
    AppWallpaperPreset preset,
    AppThemeColors colors,
  ) {
    switch (preset) {
      case AppWallpaperPreset.none:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.card, colors.cardAlt],
            ),
            border: Border.all(color: colors.divider),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.textMuted.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: AppAssetIcon(
                    assetPath: AppAssets.close,
                    size: 15,
                    color: colors.textMuted,
                    semanticLabel: 'Không nền',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Giao diện phẳng',
                  style: GoogleFonts.inter(
                    color: colors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );

      case AppWallpaperPreset.warehouseGrid:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A192F), Color(0xFF1E3A8A)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SvgPicture.asset(
                AppAssets.bgWarehouseGrid,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              Positioned(
                bottom: 6,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'BLUEPRINT KHO',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case AppWallpaperPreset.techDots:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SvgPicture.asset(
                AppAssets.bgTechDots,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              Positioned(
                bottom: 6,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'CYBER MATRIX',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case AppWallpaperPreset.meshEmerald:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF064E3B), Color(0xFF047857)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SvgPicture.asset(
                AppAssets.bgMeshEmerald,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              Positioned(
                bottom: 6,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'SÓNG LỤC BẢO',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case AppWallpaperPreset.geometric:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B0764), Color(0xFF6B21A8)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SvgPicture.asset(
                AppAssets.bgGeometricShapes,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              Positioned(
                bottom: 6,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC026D3).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'KHỐI LẬP THỂ',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case AppWallpaperPreset.warehousePanorama:
        return Container(
          decoration: const BoxDecoration(color: Color(0xFF0F172A)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                AppAssets.authWarehousePanoramaV2,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 6,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ẢNH KHO THẬT',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
    }
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
                          ? (context.isEnglish
                                ? 'Uploaded custom avatar'
                                : 'Ảnh cá nhân đã tải')
                          : (avatarState.preset?.localizedLabel(
                                  context.isEnglish,
                                ) ??
                                (context.isEnglish
                                    ? 'Avatar preset'
                                    : 'Mẫu avatar')),
                      style: GoogleFonts.inter(
                        color: colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      avatarState.hasCustomImage
                          ? (context.isEnglish
                                ? 'Personal image from device'
                                : 'Ảnh từ tệp thiết bị')
                          : (context.isEnglish
                                ? 'Branding: ${avatarState.preset?.localizedCategory(true) ?? "System"}'
                                : 'Bộ nhận diện: ${avatarState.preset?.category ?? "Hệ thống"}'),
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
                  semanticLabel: context.tr.settings.chooseAvatarPreset,
                ),
                label: Text(
                  context.tr.settings.chooseAvatarPreset,
                  style: GoogleFonts.inter(fontSize: 12),
                ),
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
          context.tr.settings.quickAvatarTitle,
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
                        preset.localizedLabel(context.isEnglish),
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
                  opacity: (opacity * 1.8).clamp(0.06, 0.35),
                  child: bgState.isCustom && bgState.hasCustomImage
                      ? (bgState.customBase64 != null &&
                                bgState.customBase64!.isNotEmpty
                            ? Image.memory(
                                base64Decode(bgState.customBase64!),
                                fit: BoxFit.cover,
                              )
                            : (bgState.customImagePath != null && !kIsWeb
                                  ? Image.file(
                                      File(bgState.customImagePath!),
                                      fit: BoxFit.cover,
                                    )
                                  : const SizedBox.shrink()))
                      : (bgState.preset != AppWallpaperPreset.none &&
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
                            : const SizedBox.shrink()),
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
