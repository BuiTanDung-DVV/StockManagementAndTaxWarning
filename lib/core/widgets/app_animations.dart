import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../assets/app_assets.dart';
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

enum AppEmptyVisual {
  generic,
  inventory,
  sales,
  people,
  finance,
  document,
  tax,
}

class AppEmpty extends StatelessWidget {
  final String message;
  final String? subtitle;
  final double size;
  final Widget? action;
  final String? assetPath;
  final AppEmptyVisual visual;
  const AppEmpty({
    super.key,
    required this.message,
    this.subtitle,
    this.size = 56,
    this.action,
    this.assetPath,
    this.visual = AppEmptyVisual.generic,
  });

  String get _resolvedAssetPath =>
      assetPath ??
      switch (visual) {
        AppEmptyVisual.generic => AppAssets.emptyGeneric,
        AppEmptyVisual.inventory => AppAssets.emptyInventory,
        AppEmptyVisual.sales => AppAssets.emptySales,
        AppEmptyVisual.people => AppAssets.emptyPeople,
        AppEmptyVisual.finance => AppAssets.emptyFinance,
        AppEmptyVisual.document => AppAssets.emptyDocument,
        AppEmptyVisual.tax => AppAssets.emptyTax,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.hasBoundedHeight && constraints.maxHeight < 240;
        final visualSize = compact && size > 36 ? 36.0 : size;
        if (compact) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: c.divider),
                      ),
                      child: AppAssetIcon(
                        assetPath: _resolvedAssetPath,
                        size: 36,
                        semanticLabel: message,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: c.textSecondary,
                                    height: 1.3,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(width: 8),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Center(
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: visualSize + 20,
                    height: visualSize + 20,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: c.divider),
                    ),
                    child: AppAssetIcon(
                      assetPath: _resolvedAssetPath,
                      size: visualSize,
                      semanticLabel: message,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 16),
                  Text(
                    message,
                    style:
                        (compact
                                ? Theme.of(context).textTheme.titleSmall
                                : Theme.of(context).textTheme.titleMedium)
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      subtitle!,
                      style:
                          (compact
                                  ? Theme.of(context).textTheme.bodySmall
                                  : Theme.of(context).textTheme.bodyMedium)
                              ?.copyWith(
                                color: c.textSecondary,
                                height: compact ? 1.3 : 1.45,
                              ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (action != null) ...[
                    SizedBox(height: compact ? 8 : 16),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
