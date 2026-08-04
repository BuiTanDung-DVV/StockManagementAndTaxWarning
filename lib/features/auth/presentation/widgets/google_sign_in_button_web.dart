import 'dart:async';
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
  late final Future<void> _initialization;
  StreamSubscription? _subscription;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initialization = GoogleAuthService.instance.initialize();
    _initialization
        .then((_) {
          if (!mounted) return;
          _subscription = GoogleAuthService.instance.accounts.listen((
            account,
          ) async {
            final idToken = account.authentication.idToken;
            if (idToken != null && idToken.isNotEmpty && widget.enabled) {
              setState(() => _loading = true);
              try {
                await widget.onIdToken(idToken);
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            }
          });
        })
        .catchError((_) {
          // Errors handled via FutureBuilder snapshot fallback
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Widget _buildFallbackButton(BuildContext context, {String? errorMessage}) {
    final c = AppThemeColors.of(context);
    final isInteractive = widget.enabled && !_loading;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: isInteractive
            ? () {
                final message =
                    errorMessage ??
                    'Chưa cấu hình GOOGLE_WEB_CLIENT_ID khi build Web.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      message,
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            : null,
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildFallbackButton(
            context,
            errorMessage: snapshot.error.toString().replaceAll(
              'Exception: ',
              '',
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _buildFallbackButton(context);
      },
    );
  }
}
