import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';

/// ─── Reusable Lottie-based animation widgets ───

class AppLoading extends StatelessWidget {
  final double size;
  final String? message;
  const AppLoading({super.key, this.size = 120, this.message});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Lottie.asset('assets/lottie/loading.json', width: size, height: size),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!, style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ],
      ]),
    );
  }
}

class AppEmpty extends StatelessWidget {
  final String message;
  final String? subtitle;
  final double size;
  final Widget? action;
  const AppEmpty({super.key, required this.message, this.subtitle, this.size = 160, this.action});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Lottie.asset('assets/lottie/empty.json', width: size, height: size, repeat: true),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: TextStyle(fontSize: 13, color: c.textSecondary), textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ]),
      ),
    );
  }
}

class AppSuccess extends StatelessWidget {
  final String? message;
  final double size;
  const AppSuccess({super.key, this.message, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Lottie.asset('assets/lottie/success.json', width: size, height: size, repeat: false),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.success), textAlign: TextAlign.center),
        ],
      ]),
    );
  }
}

class AppError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final double size;
  const AppError({super.key, required this.message, this.onRetry, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Lottie.asset('assets/lottie/error.json', width: size, height: size, repeat: true),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 14, color: AppColors.danger), textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ]),
      ),
    );
  }
}
