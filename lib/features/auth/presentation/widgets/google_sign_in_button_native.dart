import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/google_auth_service.dart';

class GoogleAuthButton extends StatefulWidget {
  const GoogleAuthButton({
    super.key,
    required this.onIdToken,
    this.enabled = true,
    this.isRegistration = false,
  });

  final Future<void> Function(String idToken) onIdToken;
  final bool enabled;
  final bool isRegistration;

  @override
  State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends State<GoogleAuthButton> {
  bool _loading = false;

  Future<void> _authenticate() async {
    if (_loading || !widget.enabled) return;
    setState(() => _loading = true);
    try {
      final token = await GoogleAuthService.instance
          .authenticateInteractively();
      await widget.onIdToken(token);
    } catch (error) {
      if (!mounted) return;
      final errorStr = error.toString().toLowerCase();
      if (!errorStr.contains('canceled') &&
          !errorStr.contains('cancelled') &&
          !errorStr.contains('dismissed')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final isInteractive = widget.enabled && !_loading;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: isInteractive ? _authenticate : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: c.card,
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.divider, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: _loading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    child: Text(
                      'G',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tiếp tục với Google',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isInteractive ? c.textPrimary : c.textMuted,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
