import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SectionedFormDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final String saveText;
  final String cancelText;
  final bool isSaving;

  const SectionedFormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onSave,
    required this.onCancel,
    this.saveText = 'Lưu',
    this.cancelText = 'Hủy',
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    
    return Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: c.divider.withValues(alpha: 0.5)),
      ),
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title, 
                    style: GoogleFonts.outfit(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    )
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: c.textSecondary),
                    onPressed: onCancel,
                    splashRadius: 24,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.divider),
            // Body
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: content,
              ),
            ),
            Divider(height: 1, color: c.divider),
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSaving ? null : onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: c.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(cancelText, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: isSaving ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(saveText, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
