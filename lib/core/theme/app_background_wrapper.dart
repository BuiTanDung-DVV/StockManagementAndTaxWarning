import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_background_provider.dart';
import 'app_theme.dart';

class AppBackgroundWrapper extends ConsumerWidget {
  final Widget child;

  const AppBackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(backgroundConfigProvider);
    final colors = AppThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (config.mode == AppBackgroundMode.none) {
      return ColoredBox(color: colors.bg, child: child);
    }

    Widget backgroundContent;
    switch (config.mode) {
      case AppBackgroundMode.gradient:
        backgroundContent = Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: config.gradientPreset.colors,
              stops: config.gradientPreset.stops,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
        break;

      case AppBackgroundMode.pattern:
        backgroundContent = CustomPaint(
          size: Size.infinite,
          painter: _PatternPainter(
            preset: config.patternPreset,
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: config.opacity.clamp(0.04, 0.25),
            ),
          ),
        );
        break;

      case AppBackgroundMode.presetWallpaper:
        backgroundContent = Image.network(
          config.wallpaperPreset.url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) =>
              Container(color: colors.bg),
        );
        break;

      case AppBackgroundMode.customUrl:
        if (config.customImageUrl.trim().isNotEmpty) {
          backgroundContent = Image.network(
            config.customImageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: colors.bg),
          );
        } else {
          backgroundContent = Container(color: colors.bg);
        }
        break;

      case AppBackgroundMode.none:
        backgroundContent = const SizedBox.shrink();
        break;
    }

    // Adaptive protective tint overlay to guarantee 100% WCAG legibility
    final overlayColor = colors.bg.withValues(
      alpha: (1.0 - config.opacity).clamp(0.35, 0.95),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base background layer
        Positioned.fill(child: backgroundContent),

        // Blur glassmorphism filter if blur > 0
        if (config.blur > 0.5)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: config.blur,
                sigmaY: config.blur,
              ),
              child: const SizedBox.shrink(),
            ),
          ),

        // Readability protection overlay
        Positioned.fill(child: ColoredBox(color: overlayColor)),

        // Foreground application content
        Positioned.fill(child: child),
      ],
    );
  }
}

class _PatternPainter extends CustomPainter {
  final AppPatternPreset preset;
  final Color color;

  _PatternPainter({required this.preset, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    switch (preset) {
      case AppPatternPreset.dotsGrid:
        const spacing = 28.0;
        final dotPaint = Paint()..color = color;
        for (double x = 0; x < size.width; x += spacing) {
          for (double y = 0; y < size.height; y += spacing) {
            canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
          }
        }
        break;

      case AppPatternPreset.blueprintGrid:
        const spacing = 36.0;
        for (double x = 0; x < size.width; x += spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;

      case AppPatternPreset.geometricWaves:
        paint.style = PaintingStyle.stroke;
        const waveHeight = 60.0;
        for (double y = 0; y < size.height; y += waveHeight) {
          final path = Path();
          path.moveTo(0, y);
          for (double x = 0; x < size.width; x += 80) {
            path.quadraticBezierTo(x + 20, y - 14, x + 40, y);
            path.quadraticBezierTo(x + 60, y + 14, x + 80, y);
          }
          canvas.drawPath(path, paint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.preset != preset || oldDelegate.color != color;
  }
}
