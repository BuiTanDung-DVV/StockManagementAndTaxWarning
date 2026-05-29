import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/toast_service.dart';

class AppConfirmModal extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final bool isDestructive;

  const AppConfirmModal({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmText = 'Xác nhận',
    this.cancelText = 'Hủy',
    this.isDestructive = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Xác nhận',
    String cancelText = 'Hủy',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmModal(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (result != true) {
      ToastService.showInfo('Đã hủy thao tác');
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    
    return AlertDialog(
      backgroundColor: c.card,
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: c.divider.withValues(alpha: 0.5)),
      ),
      title: Text(
        title, 
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: c.textPrimary)
      ),
      content: Text(
        message, 
        style: TextStyle(color: c.textSecondary, fontSize: 15, height: 1.5)
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: c.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(cancelText, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppColors.danger : Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(confirmText, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
