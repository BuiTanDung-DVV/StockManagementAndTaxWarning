import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;
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
    _initialization = _initializeWebAuth();
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

  Future<void> _initializeWebAuth() async {
    // Bảo đảm web implementation đã được đăng ký trước khi tạo singleton.
    // Một số bản build release có thể chạy widget trước registrant tự động.
    if (GoogleSignInPlatform.instance is! GoogleSignInPlugin) {
      GoogleSignInPlugin.registerWith(webPluginRegistrar);
    }
    await GoogleAuthService.instance.initialize();
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
          return Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: const Text(
              'Không thể tải đăng nhập Google',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done || _loading) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          height: 60,
          child: Center(
            child: IgnorePointer(
              ignoring: !widget.enabled,
              child: Opacity(
                opacity: widget.enabled ? 1 : 0.55,
                child: google_web.renderButton(
                  configuration: google_web.GSIButtonConfiguration(
                    type: google_web.GSIButtonType.standard,
                    theme: google_web.GSIButtonTheme.outline,
                    size: google_web.GSIButtonSize.large,
                    text: google_web.GSIButtonText.continueWith,
                    shape: google_web.GSIButtonShape.rectangular,
                    minimumWidth: 250,
                    locale: 'vi',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
