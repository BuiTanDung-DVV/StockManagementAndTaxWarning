import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';

/// ─── Reusable Lottie-based animation widgets ───

class AppLoading extends StatelessWidget {
  final double size;
  final String? message;
  const AppLoading({super.key, this.size = 56, this.message});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset('assets/lottie/loading.json', width: size, height: size),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class AppEmpty extends StatelessWidget {
  final String message;
  final String? subtitle;
  final double size;
  final Widget? action;
  const AppEmpty({
    super.key,
    required this.message,
    this.subtitle,
    this.size = 72,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/lottie/empty.json',
                width: size,
                height: size,
                repeat: false,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textSecondary,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            'assets/lottie/success.json',
            width: size,
            height: size,
            repeat: false,
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class AppError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final double size;
  const AppError({
    super.key,
    required this.message,
    this.onRetry,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.hasBoundedHeight && constraints.maxHeight < 220;
        final resolvedSize = compact && size > 44 ? 44.0 : size;
        final spacing = compact ? 8.0 : 16.0;

        return Center(
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/lottie/error.json',
                  width: resolvedSize,
                  height: resolvedSize,
                  repeat: true,
                ),
                SizedBox(height: spacing),
                Text(
                  message,
                  style: const TextStyle(fontSize: 14, color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  SizedBox(height: spacing),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Thử lại'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class AppInlineError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppInlineError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: c.textSecondary, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
