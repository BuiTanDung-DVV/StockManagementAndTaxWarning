import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;
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

  @override
  void initState() {
    super.initState();
    _initialization = GoogleAuthService.instance.initialize();
    _initialization.then((_) {
      if (!mounted) return;
      _subscription = GoogleAuthService.instance.accounts.listen((
        account,
      ) async {
        final idToken = account.authentication.idToken;
        if (idToken != null && idToken.isNotEmpty && widget.enabled) {
          await widget.onIdToken(idToken);
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            snapshot.error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return IgnorePointer(
          ignoring: !widget.enabled,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.55,
            child: google_web.renderButton(
              configuration: google_web.GSIButtonConfiguration(
                type: google_web.GSIButtonType.standard,
                theme: google_web.GSIButtonTheme.outline,
                size: google_web.GSIButtonSize.large,
                text: google_web.GSIButtonText.continueWith,
                shape: google_web.GSIButtonShape.pill,
                minimumWidth: 320,
                locale: 'vi',
              ),
            ),
          ),
        );
      },
    );
  }
}
