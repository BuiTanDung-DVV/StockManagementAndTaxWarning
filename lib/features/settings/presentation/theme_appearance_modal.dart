import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_background_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/avatar_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_avatar.dart';

class ThemeAppearanceModal extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const ThemeAppearanceModal({super.key, this.initialTabIndex = 0});

  static Future<void> show(BuildContext context, {int initialTabIndex = 0}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ThemeAppearanceModal(initialTabIndex: initialTabIndex),
    );
  }

  @override
  ConsumerState<ThemeAppearanceModal> createState() =>
      _ThemeAppearanceModalState();
}

class _ThemeAppearanceModalState extends ConsumerState<ThemeAppearanceModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _customWallpaperUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    final bgConfig = ref.read(backgroundConfigProvider);
    _customWallpaperUrlCtrl.text = bgConfig.customImageUrl;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customWallpaperUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      color: primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tùy biến giao diện & hình nền',
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: colors.cardAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: colors.textSecondary,
                labelStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.color_lens_outlined, size: 18),
                    text: 'Màu & Chủ đề',
                  ),
                  Tab(
                    icon: Icon(Icons.wallpaper_rounded, size: 18),
                    text: 'Hình nền',
                  ),
                  Tab(
                    icon: Icon(Icons.account_circle_outlined, size: 18),
                    text: 'Ảnh đại diện',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab contents
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildThemeAndColorTab(colors, primary),
                  _buildBackgroundTab(colors, primary),
                  _buildAvatarTab(colors, primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB 1: Theme Mode & Brand Colors
  // ─────────────────────────────────────────────
  Widget _buildThemeAndColorTab(AppThemeColors colors, Color primary) {
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentBrandColor = ref.watch(brandColorProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Preview Card
          _buildLivePreviewCard(colors, primary),
          const SizedBox(height: 20),

          // Theme Mode Selector
          Text(
            'CHẾ ĐỘ HIỂN THỊ',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ThemeModeButton(
                  title: 'Sáng',
                  icon: Icons.light_mode_rounded,
                  selected: currentThemeMode == ThemeMode.light,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeModeButton(
                  title: 'Tối',
                  icon: Icons.dark_mode_rounded,
                  selected: currentThemeMode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeModeButton(
                  title: 'Hệ thống',
                  icon: Icons.settings_brightness_rounded,
                  selected: currentThemeMode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.system),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Brand Color Palette
          Text(
            'MÀU SẮC CHỦ ĐẠO (BRAND ACCENT)',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Áp dụng cho nút bấm chính, biểu tượng, viền thẻ nổi bật và thanh điều hướng.',
            style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemCount: AppBrandColor.values.length,
            itemBuilder: (context, index) {
              final item = AppBrandColor.values[index];
              final isSelected = item == currentBrandColor;

              return InkWell(
                onTap: () {
                  ref.read(brandColorProvider.notifier).setBrandColor(item);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? item.color.withValues(alpha: 0.12)
                        : colors.cardAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? item.color : colors.divider,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected ? item.color : colors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: item.color,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewCard(AppThemeColors colors, Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Xem trước trực tiếp',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.auto_awesome_rounded, color: primary, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'SmartStock & Cảnh báo thuế',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Trực quan hóa số liệu tồn kho, doanh thu và an toàn pháp lý',
            style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Nút bấm chính'),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withValues(alpha: 0.5)),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Nút phụ'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB 2: Background & Wallpaper Customization
  // ─────────────────────────────────────────────
  Widget _buildBackgroundTab(AppThemeColors colors, Color primary) {
    final bgConfig = ref.watch(backgroundConfigProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode selector chips
          Text(
            'CHỌN KIỂU HÌNH NỀN',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final mode in AppBackgroundMode.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(mode.label),
                      selected: bgConfig.mode == mode,
                      onSelected: (val) {
                        if (val) {
                          ref
                              .read(backgroundConfigProvider.notifier)
                              .setMode(mode);
                        }
                      },
                      selectedColor: primary,
                      labelStyle: TextStyle(
                        color: bgConfig.mode == mode
                            ? Colors.white
                            : colors.textPrimary,
                        fontSize: 12,
                        fontWeight: bgConfig.mode == mode
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Sub-options based on mode
          if (bgConfig.mode == AppBackgroundMode.gradient) ...[
            Text(
              'BỘ SƯU TẬP GRADIENT CHUYỂN MÀU',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.3,
              ),
              itemCount: AppGradientPreset.values.length,
              itemBuilder: (context, index) {
                final preset = AppGradientPreset.values[index];
                final isSelected = bgConfig.gradientPreset == preset;

                return InkWell(
                  onTap: () => ref
                      .read(backgroundConfigProvider.notifier)
                      .setGradient(preset),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? primary : colors.divider,
                        width: isSelected ? 2.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              colors: preset.colors,
                              stops: preset.stops,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            preset.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: primary,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ] else if (bgConfig.mode == AppBackgroundMode.pattern) ...[
            Text(
              'HỌA TIẾT CẤU TRÚC TINH GỌN',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            for (final pattern in AppPatternPreset.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: bgConfig.patternPreset == pattern
                          ? primary
                          : colors.divider,
                      width: bgConfig.patternPreset == pattern ? 2 : 1,
                    ),
                  ),
                  tileColor: bgConfig.patternPreset == pattern
                      ? primary.withValues(alpha: 0.08)
                      : colors.cardAlt,
                  leading: Icon(
                    Icons.grid_4x4_rounded,
                    color: bgConfig.patternPreset == pattern
                        ? primary
                        : colors.textSecondary,
                  ),
                  title: Text(
                    pattern.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    pattern.description,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                  trailing: bgConfig.patternPreset == pattern
                      ? Icon(Icons.check_circle_rounded, color: primary)
                      : null,
                  onTap: () => ref
                      .read(backgroundConfigProvider.notifier)
                      .setPattern(pattern),
                ),
              ),
          ] else if (bgConfig.mode == AppBackgroundMode.presetWallpaper) ...[
            Text(
              'BỘ SƯU TẬP ẢNH NỀN KHÔNG GIAN',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
              ),
              itemCount: AppWallpaperPreset.values.length,
              itemBuilder: (context, index) {
                final wp = AppWallpaperPreset.values[index];
                final isSelected = bgConfig.wallpaperPreset == wp;

                return InkWell(
                  onTap: () => ref
                      .read(backgroundConfigProvider.notifier)
                      .setWallpaper(wp),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? primary : colors.divider,
                        width: isSelected ? 2.5 : 1.0,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(wp.url, fit: BoxFit.cover),
                          Container(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  wp.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: primary,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ] else if (bgConfig.mode == AppBackgroundMode.customUrl) ...[
            Text(
              'NHẬP LIÊN KẾT HÌNH ẢNH (URL)',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customWallpaperUrlCtrl,
                    decoration: InputDecoration(
                      hintText: 'https://example.com/wallpaper.jpg',
                      prefixIcon: const Icon(Icons.link_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    style: TextStyle(fontSize: 12, color: colors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final url = _customWallpaperUrlCtrl.text.trim();
                    ref
                        .read(backgroundConfigProvider.notifier)
                        .setCustomImageUrl(url);
                  },
                  child: const Text('Áp dụng'),
                ),
              ],
            ),
          ],

          if (bgConfig.mode != AppBackgroundMode.none) ...[
            const SizedBox(height: 24),
            Divider(color: colors.divider, height: 1),
            const SizedBox(height: 16),

            // Opacity slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ĐỘ MỜ HÌNH NỀN',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  '${(bgConfig.opacity * 100).round()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: bgConfig.opacity,
              min: 0.05,
              max: 0.70,
              divisions: 13,
              activeColor: primary,
              onChanged: (val) =>
                  ref.read(backgroundConfigProvider.notifier).setOpacity(val),
            ),

            // Blur slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LÀM MỜ KÍNH (GLASSMORPHISM BLUR)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  '${bgConfig.blur.round()} px',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: bgConfig.blur,
              min: 0.0,
              max: 30.0,
              divisions: 15,
              activeColor: primary,
              onChanged: (val) =>
                  ref.read(backgroundConfigProvider.notifier).setBlur(val),
            ),

            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  ref.read(backgroundConfigProvider.notifier).resetToDefault();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Khôi phục nền mặc định'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB 3: Avatar Customization
  // ─────────────────────────────────────────────
  Widget _buildAvatarTab(AppThemeColors colors, Color primary) {
    final currentAvatar = ref.watch(userAvatarProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Avatar Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.divider),
            ),
            child: Row(
              children: [
                const AppAvatar(size: 64, borderWidth: 3),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentAvatar.hasCustomUrl
                            ? 'Ảnh liên kết tùy chỉnh'
                            : currentAvatar.currentPreset.label,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hiển thị trên ảnh hồ sơ cá nhân, trang cài đặt và thanh tiêu đề ứng dụng.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Preset Avatars Grid
          Text(
            'BỘ SƯU TẬP 12 AVATAR DOANH NGHIỆP',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: kPresetAvatars.length,
            itemBuilder: (context, index) {
              final item = kPresetAvatars[index];
              final isSelected =
                  !currentAvatar.hasCustomUrl &&
                  currentAvatar.presetId == item.id;

              return InkWell(
                onTap: () =>
                    ref.read(userAvatarProvider.notifier).selectPreset(item.id),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary.withValues(alpha: 0.12)
                        : colors.cardAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? primary : colors.divider,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.bgColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          item.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? primary : colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeModeButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: selected ? primary.withValues(alpha: 0.12) : colors.cardAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? primary : colors.divider,
          width: selected ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? primary : colors.textSecondary,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? primary : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
