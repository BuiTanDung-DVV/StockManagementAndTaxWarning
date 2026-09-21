import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_provider.dart';

class AppAvatar extends ConsumerWidget {
  final double size;
  final double borderWidth;
  final Color? borderColor;
  final bool showEditBadge;
  final VoidCallback? onTap;
  final String? fallbackInitials;

  const AppAvatar({
    super.key,
    this.size = 40,
    this.borderWidth = 1.5,
    this.borderColor,
    this.showEditBadge = false,
    this.onTap,
    this.fallbackInitials,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarConfig = ref.watch(userAvatarProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final colors = AppThemeColors.of(context);
    final effectiveBorderColor = borderColor ?? primary.withValues(alpha: 0.3);

    Widget avatarContent;
    if (avatarConfig.hasCustomUrl) {
      avatarContent = Image.network(
        avatarConfig.customUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildPreset(avatarConfig.currentPreset, fallbackInitials, colors),
      );
    } else {
      avatarContent = _buildPreset(
        avatarConfig.currentPreset,
        fallbackInitials,
        colors,
      );
    }

    final avatarBox = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: effectiveBorderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(child: avatarContent),
    );

    if (!showEditBadge && onTap == null) {
      return avatarBox;
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatarBox,
          if (showEditBadge)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: EdgeInsets.all(size * 0.08),
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.card, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: (size * 0.28).clamp(10.0, 18.0),
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreset(
    PresetAvatarItem preset,
    String? initials,
    AppThemeColors colors,
  ) {
    return Container(
      color: preset.bgColor,
      alignment: Alignment.center,
      child: Text(
        preset.emoji,
        style: TextStyle(fontSize: size * 0.52, height: 1.0),
      ),
    );
  }
}
