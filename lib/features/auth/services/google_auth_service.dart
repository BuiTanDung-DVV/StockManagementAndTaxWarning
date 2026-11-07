import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthConfigurationException implements Exception {
  const GoogleAuthConfigurationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();
  // Public OAuth identifier, also used by build_vercel.sh. Local release builds
  // must keep Google sign-in working even when no --dart-define is supplied.
  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '124075638912-hk0076lmjvgqa0iqec75aerpoe4lcpfq.apps.googleusercontent.com',
  );

  static const _envServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  final GoogleSignIn _signIn = GoogleSignIn.instance;
  Future<void>? _initialization;

  Future<void> initialize() {
    return _initialization ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    if (kIsWeb) {
      if (webClientId.isEmpty) {
        throw const GoogleAuthConfigurationException(
          'Thiếu GOOGLE_WEB_CLIENT_ID trong cấu hình build.',
        );
      }
      await _signIn.initialize(clientId: webClientId);
      return;
    }
    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (isApple && _iosClientId.isEmpty) {
      throw const GoogleAuthConfigurationException(
        'Thiếu GOOGLE_IOS_CLIENT_ID khi build ứng dụng Apple.',
      );
    }
    if (!isApple && _envServerClientId.isEmpty) {
      throw const GoogleAuthConfigurationException(
        'Thiếu GOOGLE_SERVER_CLIENT_ID trong cấu hình build.',
      );
    }
    await _signIn.initialize(
      clientId: isApple ? _iosClientId : null,
      serverClientId: isApple ? null : _envServerClientId,
    );
  }

  Stream<GoogleSignInAccount> get accounts async* {
    await initialize();
    await for (final event in _signIn.authenticationEvents) {
      if (event is GoogleSignInAuthenticationEventSignIn) yield event.user;
    }
  }

  Future<String> authenticateInteractively() async {
    await initialize();
    if (!_signIn.supportsAuthenticate()) {
      throw const GoogleAuthConfigurationException(
        'Nền tảng này cần dùng nút Google do Google cung cấp.',
      );
    }
    final account = await _signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleAuthConfigurationException(
        'Google không trả về ID token hợp lệ.',
      );
    }
    return idToken;
  }

  Future<void> signOut() async {
    try {
      await initialize();
      await _signIn.signOut();
    } catch (_) {
      // Phiên SmartStock vẫn được thu hồi ngay cả khi Google sign-out thất bại.
    }
  }
}
