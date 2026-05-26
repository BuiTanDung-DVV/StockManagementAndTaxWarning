import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ToastService {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(String message) {
    _showSnackBar(message, AppColors.success);
  }

  static void showError(String message) {
    _showSnackBar(message, AppColors.danger);
  }

  static void showWarning(String message) {
    _showSnackBar(message, AppColors.warning);
  }

  static void _showSnackBar(String message, Color backgroundColor) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars(); // Clear existing to prevent lingering toast
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        showCloseIcon: true,
        closeIconColor: Colors.white,
      ),
    );
  }
}
