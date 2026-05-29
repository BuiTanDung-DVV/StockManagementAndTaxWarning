import 'package:flutter/material.dart';
import 'package:bot_toast/bot_toast.dart';
import '../theme/app_theme.dart';

class ToastService {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(String message) {
    _showSnackBar(message, AppColors.success);
  }

  static void showError(String message) {
    _showSnackBar(message, AppColors.danger);
  }

  static void showInfo(String message) {
    _showSnackBar(message, AppColors.info);
  }

  static void showWarning(String message) {
    _showSnackBar(message, AppColors.warning);
  }

  static void _showSnackBar(String message, Color backgroundColor) {
    BotToast.showText(
      text: message,
      contentColor: backgroundColor,
      textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      duration: const Duration(seconds: 3),
    );
  }
}
