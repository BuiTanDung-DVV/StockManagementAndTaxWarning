import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppNavigationBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AppNavigationBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Tooltip(
      message: 'Quay lại',
      child: Semantics(
        button: true,
        label: 'Quay lại',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            hoverColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: .06),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.cardAlt,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: colors.divider),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 19,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppNavigationBackLeading extends StatelessWidget {
  final VoidCallback onPressed;

  const AppNavigationBackLeading({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Center(child: AppNavigationBackButton(onPressed: onPressed)),
    );
  }
}
