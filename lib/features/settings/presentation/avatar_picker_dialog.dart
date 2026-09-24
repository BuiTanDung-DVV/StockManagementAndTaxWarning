import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/avatar_provider.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_avatar.dart';

class AvatarPickerDialog extends ConsumerStatefulWidget {
  const AvatarPickerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AvatarPickerDialog(),
    );
  }

  @override
  ConsumerState<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends ConsumerState<AvatarPickerDialog> {
  bool _isUploading = false;

  Future<void> _pickCustomImage() async {
    setState(() => _isUploading = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = base64Encode(bytes);
        await ref
            .read(userAvatarProvider.notifier)
            .setCustomImage(
              filePath: kIsWeb ? null : picked.path,
              base64Data: base64String,
            );
        ToastService.showSuccess('Đã cập nhật ảnh đại diện mới!');
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      ToastService.showError('Không thể tải ảnh lên: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final avatarState = ref.watch(userAvatarProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: AppAssetIcon(
                      assetPath: AppAssets.avatar,
                      size: 22,
                      color: Theme.of(context).colorScheme.primary,
                      semanticLabel: context.tr.settings.tabAvatar,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr.settings.chooseAvatarTitle,
                          style: GoogleFonts.inter(
                            color: colors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          context.tr.settings.chooseAvatarSubtitle,
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
              const SizedBox(height: 20),

              // Preview Current Avatar
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
                                      : 'Ảnh tùy chỉnh đã tải')
                                : (avatarState.preset?.localizedLabel(
                                        context.isEnglish,
                                      ) ??
                                      (context.isEnglish
                                          ? 'No preset selected'
                                          : 'Chưa chọn mẫu')),
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
                                      ? 'Personal image uploaded from device'
                                      : 'Ảnh cá nhân tải lên từ thiết bị')
                                : (context.isEnglish
                                      ? 'Identity: ${avatarState.preset?.localizedCategory(true) ?? "System"}'
                                      : 'Nhận diện: ${avatarState.preset?.category ?? "Hệ thống"}'),
                            style: GoogleFonts.inter(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickCustomImage,
                      icon: AppAssetIcon(
                        assetPath: AppAssets.upload,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                        semanticLabel: context.tr.settings.uploadFromDevice,
                      ),
                      label: Text(
                        _isUploading
                            ? (context.isEnglish
                                  ? 'Uploading...'
                                  : 'Đang tải...')
                            : (context.isEnglish ? 'Upload' : 'Tải ảnh'),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Text(
                context.tr.settings.enterpriseAvatarCollection,
                style: GoogleFonts.inter(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),

              // Presets Grid
              SizedBox(
                height: 260,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: AppAvatarPreset.values.length,
                  itemBuilder: (context, index) {
                    final preset = AppAvatarPreset.values[index];
                    final isSelected =
                        !avatarState.hasCustomImage &&
                        avatarState.preset == preset;

                    return InkWell(
                      onTap: () {
                        ref.read(userAvatarProvider.notifier).setPreset(preset);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.08)
                              : colors.cardAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : colors.divider,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                AppAvatar(
                                  size: 46,
                                  assetPath: preset.assetPath,
                                ),
                                if (isSelected)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.card,
                                          width: 1.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: const AppAssetIcon(
                                        assetPath: AppAssets.check,
                                        size: 10,
                                        color: Colors.white,
                                        semanticLabel: 'Đã chọn',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              preset.localizedLabel(context.isEnglish),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : colors.textPrimary,
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ref.read(userAvatarProvider.notifier).resetDefault();
                      ToastService.showInfo(
                        context.isEnglish
                            ? 'Default avatar restored'
                            : 'Đã đặt lại ảnh đại diện mặc định',
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
                        horizontal: 20,
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
            ],
          ),
        ),
      ),
    );
  }
}
