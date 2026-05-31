import 'package:flutter/material.dart';
import 'package:bot_toast/bot_toast.dart';
import '../theme/app_theme.dart';

class ToastService {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(String message) {
    _showSnackBar(message, AppColors.success, Icons.check_circle_rounded);
  }

  static void showError(String message) {
    _showSnackBar(message, AppColors.danger, Icons.error_rounded);
  }

  static void showInfo(String message) {
    _showSnackBar(message, AppColors.info, Icons.info_rounded);
  }

  static void showWarning(String message) {
    _showSnackBar(message, AppColors.warning, Icons.warning_rounded);
  }

  static void _showSnackBar(String message, Color backgroundColor, IconData icon) {
    BotToast.showCustomNotification(
      toastBuilder: (cancelFunc) {
        return Card(
          color: backgroundColor,
          elevation: 8,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      duration: const Duration(seconds: 3),
      align: const Alignment(0, -0.9),
    );
  }
}
