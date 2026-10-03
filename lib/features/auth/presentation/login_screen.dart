import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/password_visibility_button.dart';
import '../../settings/providers/shop_provider.dart';
import '../providers/auth_provider.dart';
import 'widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _prefRememberMe = 'auth_remember_login';
  static const _prefSavedUsername = 'auth_saved_username';
  static const _prefSavedPassword = 'auth_saved_password';

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isAutoLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_prefRememberMe) ?? false;
      if (!remember) return;

      final savedUser = prefs.getString(_prefSavedUsername) ?? '';
      final savedPass = prefs.getString(_prefSavedPassword) ?? '';

      if (!mounted) return;
      setState(() {
        _rememberMe = true;
        if (savedUser.isNotEmpty) _usernameController.text = savedUser;
        if (savedPass.isNotEmpty) _passwordController.text = savedPass;
      });

      final authNotifier = ref.read(authProvider.notifier);
      if (savedUser.isNotEmpty &&
          savedPass.isNotEmpty &&
          !authNotifier.wasManualLogout) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final currentAuth = ref.read(authProvider);
          if (currentAuth.isLoggedIn) {
            _navigateAfterAuthentication();
            return;
          }
          setState(() => _isAutoLoggingIn = true);
          await _login();
          if (mounted) {
            setState(() => _isAutoLoggingIn = false);
          }
        });
      } else if (authNotifier.wasManualLogout) {
        authNotifier.clearManualLogout();
      }
    } catch (_) {}
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final success = await ref
        .read(authProvider.notifier)
        .login(username, password);

    if (!success) {
      if (mounted) setState(() => _isAutoLoggingIn = false);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool(_prefRememberMe, true);
        await prefs.setString(_prefSavedUsername, username);
        await prefs.setString(_prefSavedPassword, password);
      } else {
        await prefs.setBool(_prefRememberMe, false);
        await prefs.remove(_prefSavedUsername);
        await prefs.remove(_prefSavedPassword);
      }
    } catch (_) {}

    if (!mounted) return;
    _navigateAfterAuthentication();
  }

  Future<void> _loginWithGoogle(String idToken) async {
    final success = await ref
        .read(authProvider.notifier)
        .authenticateWithGoogle(idToken: idToken, createIfMissing: false);
    if (!success || !mounted) return;
    _navigateAfterAuthentication();
  }

  void _navigateAfterAuthentication() {
    if (!mounted) return;
    try {
      final auth = ref.read(authProvider);
      if (!auth.isOnboarded) {
        context.go('/onboarding');
        return;
      }

      final shopState = ref.read(shopProvider);
      context.go(shopState.isPending ? '/waiting-approval' : '/');
    } catch (_) {
      // Allow standalone widget test environments where GoRouter is not injected
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Đăng nhập',
      subtitle: 'Nhập thông tin tài khoản để tiếp tục làm việc.',
      compactAuthLayout: true,
      body: _LoginForm(
        usernameController: _usernameController,
        passwordController: _passwordController,
        passwordFocus: _passwordFocus,
        obscurePassword: _obscurePassword,
        rememberMe: _rememberMe,
        loading: auth.isLoading || _isAutoLoggingIn,
        error: auth.error,
        onTogglePassword: () {
          setState(() => _obscurePassword = !_obscurePassword);
        },
        onRememberMeChanged: (val) {
          setState(() => _rememberMe = val);
        },
        onLogin: _login,
        onGoogleIdToken: _loginWithGoogle,
        onForgotPassword: () => context.push('/forgot-password'),
        onRegister: () => context.push('/register'),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final bool rememberMe;
  final bool loading;
  final String? error;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onLogin;
  final Future<void> Function(String idToken) onGoogleIdToken;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;

  const _LoginForm({
    required this.usernameController,
    required this.passwordController,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.rememberMe,
    required this.loading,
    required this.error,
    required this.onTogglePassword,
    required this.onRememberMeChanged,
    required this.onLogin,
    required this.onGoogleIdToken,
    required this.onForgotPassword,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: usernameController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            onSubmitted: (_) => passwordFocus.requestFocus(),
            decoration: const InputDecoration(
              labelText: 'Gmail hoặc tên đăng nhập',
              hintText: 'Nhập tài khoản',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: passwordController,
            focusNode: passwordFocus,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => onLogin(),
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              hintText: 'Nhập mật khẩu',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: PasswordVisibilityButton(
                obscureText: obscurePassword,
                onPressed: onTogglePassword,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: loading
                      ? null
                      : () => onRememberMeChanged(!rememberMe),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: rememberMe,
                          onChanged: loading
                              ? null
                              : (val) => onRememberMeChanged(val ?? false),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ghi nhớ đăng nhập',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: loading ? null : onForgotPassword,
                  child: const Text('Quên mật khẩu?'),
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: loading ? null : onLogin,
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Đăng nhập'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: Divider(color: colors.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'hoặc',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ),
              Expanded(child: Divider(color: colors.divider)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GoogleAuthButton(enabled: !loading, onIdToken: onGoogleIdToken),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Chưa có tài khoản?',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
              TextButton(
                onPressed: onRegister,
                child: const Text('Đăng ký ngay'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
