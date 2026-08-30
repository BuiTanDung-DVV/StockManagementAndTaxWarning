import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PasswordVisibilityButton extends StatelessWidget {
  const PasswordVisibilityButton({
    super.key,
    required this.obscureText,
    required this.onPressed,
  });

  final bool obscureText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final label = obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu';

    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textSecondary,
        side: BorderSide.none,
        minimumSize: const Size.square(48),
        fixedSize: const Size.square(48),
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
      ),
      icon: Icon(
        obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        size: 20,
        semanticLabel: label,
      ),
    );
  }
}
