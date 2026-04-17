import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_theme.dart';

class AppVersionWidget extends StatelessWidget {
  final TextStyle? style;
  const AppVersionWidget({super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final packageInfo = snapshot.data!;
        final version = packageInfo.version;
        final buildNumber = packageInfo.buildNumber;
        final c = AppThemeColors.of(context);
        
        return Text(
          'Phiên bản $version',
          style: style ?? TextStyle(
            color: c.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
