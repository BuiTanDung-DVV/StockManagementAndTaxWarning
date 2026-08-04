import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/google_auth_service.dart';

class GoogleColorIcon extends StatelessWidget {
  const GoogleColorIcon({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGLogoPainter()),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24.0;

    // Blue path
    final Path bluePath = Path()
      ..moveTo(23.745 * s, 12.27 * s)
      ..cubicTo(
        23.745 * s,
        11.47 * s,
        23.675 * s,
        10.7 * s,
        23.545 * s,
        9.96 * s,
      )
      ..lineTo(12.0 * s, 9.96 * s)
      ..lineTo(12.0 * s, 14.63 * s)
      ..lineTo(18.59 * s, 14.63 * s)
      ..cubicTo(18.3 * s, 16.17 * s, 17.43 * s, 17.48 * s, 16.12 * s, 18.35 * s)
      ..lineTo(16.12 * s, 21.46 * s)
      ..lineTo(20.0 * s, 21.46 * s)
      ..cubicTo(
        22.28 * s,
        19.36 * s,
        23.745 * s,
        16.27 * s,
        23.745 * s,
        12.27 * s,
      )
      ..close();
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF4285F4));

    // Green path
    final Path greenPath = Path()
      ..moveTo(12.0 * s, 24.0 * s)
      ..cubicTo(15.24 * s, 24.0 * s, 17.96 * s, 22.93 * s, 19.99 * s, 21.46 * s)
      ..lineTo(16.12 * s, 18.35 * s)
      ..cubicTo(15.04 * s, 19.08 * s, 13.64 * s, 19.51 * s, 12.0 * s, 19.51 * s)
      ..cubicTo(8.87 * s, 19.51 * s, 6.22 * s, 17.39 * s, 5.27 * s, 14.54 * s)
      ..lineTo(1.26 * s, 14.54 * s)
      ..lineTo(1.26 * s, 17.65 * s)
      ..cubicTo(3.29 * s, 21.68 * s, 7.45 * s, 24.0 * s, 12.0 * s, 24.0 * s)
      ..close();
    canvas.drawPath(greenPath, Paint()..color = const Color(0xFF34A853));

    // Yellow path
    final Path yellowPath = Path()
      ..moveTo(5.27 * s, 14.54 * s)
      ..cubicTo(5.03 * s, 13.82 * s, 4.9 * s, 13.05 * s, 4.9 * s, 12.26 * s)
      ..cubicTo(4.9 * s, 11.47 * s, 5.03 * s, 10.7 * s, 5.27 * s, 9.98 * s)
      ..lineTo(5.27 * s, 6.87 * s)
      ..lineTo(1.26 * s, 6.87 * s)
      ..cubicTo(0.46 * s, 8.47 * s, 0.0 * s, 10.31 * s, 0.0 * s, 12.26 * s)
      ..cubicTo(0.0 * s, 14.21 * s, 0.46 * s, 16.05 * s, 1.26 * s, 17.65 * s)
      ..lineTo(5.27 * s, 14.54 * s)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFFBBC05));

    // Red path
    final Path redPath = Path()
      ..moveTo(12.0 * s, 5.01 * s)
      ..cubicTo(13.76 * s, 5.01 * s, 15.34 * s, 5.62 * s, 16.58 * s, 6.81 * s)
      ..lineTo(20.08 * s, 3.31 * s)
      ..cubicTo(17.96 * s, 1.33 * s, 15.24 * s, 0.0 * s, 12.0 * s, 0.0 * s)
      ..cubicTo(7.45 * s, 0.0 * s, 3.29 * s, 2.32 * s, 1.26 * s, 6.35 * s)
      ..lineTo(5.27 * s, 9.46 * s)
      ..cubicTo(6.22 * s, 6.61 * s, 8.87 * s, 5.01 * s, 12.0 * s, 5.01 * s)
      ..close();
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
        .catchError((_) {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

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

  Widget _buildButton(BuildContext context) {
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
                  const GoogleColorIcon(size: 20),
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
        if (snapshot.connectionState != ConnectionState.done && _loading) {
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
        return _buildButton(context);
      },
    );
  }
}
