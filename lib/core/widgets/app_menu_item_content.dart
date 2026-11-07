import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import '../theme/app_theme.dart';

class AppMenuItemContent extends StatelessWidget {
  final String assetPath;
  final String label;

  const AppMenuItemContent({
    super.key,
    required this.assetPath,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAssetIcon(
          assetPath: assetPath,
          size: 20,
          color: colors.textSecondary,
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    );
  }
}
