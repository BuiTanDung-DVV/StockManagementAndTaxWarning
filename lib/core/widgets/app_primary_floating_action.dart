import 'package:flutter/material.dart';

import '../assets/app_assets.dart';

class AppPrimaryFloatingAction extends StatelessWidget {
  final String label;
  final String assetPath;
  final VoidCallback onPressed;
  final Object heroTag;

  const AppPrimaryFloatingAction({
    super.key,
    required this.label,
    required this.assetPath,
    required this.onPressed,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: onPressed,
        icon: AppAssetIcon(
          assetPath: assetPath,
          size: 19,
          color: Colors.white,
          semanticLabel: label,
        ),
        label: Text(label),
      ),
    );
  }
}

class AppPrimaryHeaderAction extends StatelessWidget {
  const AppPrimaryHeaderAction({
    super.key,
    required this.label,
    required this.assetPath,
    required this.onPressed,
    required this.heroTag,
  });

  final String label;
  final String assetPath;
  final VoidCallback? onPressed;
  final Object heroTag;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: FloatingActionButton.small(
        heroTag: heroTag,
        elevation: 0,
        onPressed: onPressed,
        child: AppAssetIcon(
          assetPath: assetPath,
          size: 18,
          color: Colors.white,
          semanticLabel: label,
        ),
      ),
    );
  }
}
