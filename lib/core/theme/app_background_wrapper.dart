import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_background_provider.dart';

class AppBackgroundWrapper extends ConsumerWidget {
  final Widget child;

  const AppBackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgState = ref.watch(appBackgroundProvider);

    if (!bgState.hasBackground) {
      return child;
    }

    Widget? backgroundContent;

    if (bgState.customBase64 != null && bgState.customBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(bgState.customBase64!);
        backgroundContent = Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } catch (_) {
        backgroundContent = null;
      }
    } else if (bgState.customImagePath != null &&
        bgState.customImagePath!.isNotEmpty &&
        !kIsWeb) {
      try {
        final file = File(bgState.customImagePath!);
        if (file.existsSync()) {
          backgroundContent = Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        }
      } catch (_) {
        backgroundContent = null;
      }
    } else if (bgState.preset != AppWallpaperPreset.none &&
        bgState.preset.assetPath.isNotEmpty) {
      final asset = bgState.preset.assetPath;
      if (asset.toLowerCase().endsWith('.svg')) {
        backgroundContent = SvgPicture.asset(
          asset,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else {
        backgroundContent = Image.asset(
          asset,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
    }

    if (backgroundContent == null) {
      return child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(opacity: bgState.opacity, child: backgroundContent),
          ),
        ),
        if (bgState.blurRadius > 0.1)
          Positioned.fill(
            child: IgnorePointer(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: bgState.blurRadius,
                  sigmaY: bgState.blurRadius,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
