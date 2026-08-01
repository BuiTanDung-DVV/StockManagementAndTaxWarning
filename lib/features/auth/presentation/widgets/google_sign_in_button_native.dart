import 'package:flutter/material.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: widget.enabled && !_loading ? _authenticate : null,
        icon: _loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.g_mobiledata_rounded, color: Colors.redAccent),
        label: Text(
          widget.isRegistration ? 'Đăng ký với Google' : 'Đăng nhập với Google',
        ),
      ),
    );
  }
}
