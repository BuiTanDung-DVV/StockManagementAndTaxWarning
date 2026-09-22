import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../assets/app_assets.dart';
import '../theme/avatar_provider.dart';

class AppAvatar extends ConsumerWidget {
  final double size;
  final String? displayName;
  final String? assetPath;
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool showEditBadge;
  final Color? borderColor;
  final double borderWidth;

  const AppAvatar({
    super.key,
    this.size = 48,
    this.displayName,
    this.assetPath,
    this.imageUrl,
    this.onTap,
    this.showEditBadge = false,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarState = ref.watch(userAvatarProvider);

    Widget avatarImage;

    // 1. Explicit assetPath passed
    if (assetPath != null) {
      if (assetPath!.isNotEmpty) {
        avatarImage = _buildAssetWidget(assetPath!, size);
      } else {
        avatarImage = _buildInitialsFallback(context, displayName, size);
      }
    }
    // 2. Custom Base64 image
    else if (avatarState.customBase64 != null &&
        avatarState.customBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(avatarState.customBase64!);
        avatarImage = Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } catch (_) {
        avatarImage = _buildInitialsFallback(context, displayName, size);
      }
    }
    // 3. Custom File path (mobile / desktop)
    else if (avatarState.customImagePath != null &&
        avatarState.customImagePath!.isNotEmpty &&
        !kIsWeb) {
      try {
        final file = File(avatarState.customImagePath!);
        if (file.existsSync()) {
          avatarImage = Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
          );
        } else {
          avatarImage = _buildInitialsFallback(context, displayName, size);
        }
      } catch (_) {
        avatarImage = _buildInitialsFallback(context, displayName, size);
      }
    }
    // 4. Remote URL
    else if ((imageUrl != null && imageUrl!.isNotEmpty) ||
        (avatarState.networkUrl != null &&
            avatarState.networkUrl!.isNotEmpty)) {
      final url = imageUrl ?? avatarState.networkUrl!;
      avatarImage = CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (_, _, _) =>
            _buildInitialsFallback(context, displayName, size),
      );
    }
    // 5. Preset from provider
    else if (avatarState.preset != null &&
        avatarState.preset!.assetPath.isNotEmpty) {
      avatarImage = _buildAssetWidget(avatarState.preset!.assetPath, size);
    }
    // 6. Default Fallback initials
    else {
      avatarImage = _buildInitialsFallback(context, displayName, size);
    }

    final hasBorder = borderWidth > 0 && borderColor != null;

    Widget content = ClipOval(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: avatarImage,
      ),
    );

    if (hasBorder) {
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        child: content,
      );
    }

    if (showEditBadge) {
      final badgeSize = (size * 0.32).clamp(18.0, 32.0);
      final primary = Theme.of(context).colorScheme.primary;

      content = Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: AppAssetIcon(
                assetPath: AppAssets.edit,
                size: badgeSize * 0.55,
                color: Colors.white,
                semanticLabel: 'Đổi ảnh đại diện',
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }

  static Widget _buildAssetWidget(String asset, double size) {
    if (asset.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
    return Image.asset(asset, width: size, height: size, fit: BoxFit.cover);
  }

  static Widget _buildInitialsFallback(
    BuildContext context,
    String? name,
    double size,
  ) {
    final clean = (name ?? '').trim();
    String initials = 'ST';
    if (clean.isNotEmpty) {
      final parts = clean.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
      } else {
        initials = clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    final theme = Theme.of(context);
    final fontSize = (size * 0.38).clamp(10.0, 36.0);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Text(
        initials,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
