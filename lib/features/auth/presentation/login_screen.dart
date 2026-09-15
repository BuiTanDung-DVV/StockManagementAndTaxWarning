import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/app_version_widget.dart';
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
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final success = await ref
        .read(authProvider.notifier)
        .login(_usernameController.text.trim(), _passwordController.text);
    if (!success || !mounted) return;

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
    final auth = ref.read(authProvider);
    if (!auth.isOnboarded) {
      context.go('/onboarding');
      return;
    }

    final shopState = ref.read(shopProvider);
    context.go(shopState.isPending ? '/waiting-approval' : '/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Đăng nhập',
      subtitle: 'Nhập thông tin tài khoản để tiếp tục làm việc.',
      footer: const Center(child: AppVersionWidget()),
      body: _LoginForm(
        usernameController: _usernameController,
        passwordController: _passwordController,
        passwordFocus: _passwordFocus,
        obscurePassword: _obscurePassword,
        loading: auth.isLoading,
        error: auth.error,
        onTogglePassword: () {
          setState(() => _obscurePassword = !_obscurePassword);
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
  final bool loading;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final Future<void> Function(String idToken) onGoogleIdToken;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;

  const _LoginForm({
    required this.usernameController,
    required this.passwordController,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.loading,
    required this.error,
    required this.onTogglePassword,
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
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            onSubmitted: (_) => passwordFocus.requestFocus(),
            decoration: const InputDecoration(
              labelText: 'Gmail hoặc tên đăng nhập',
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
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: PasswordVisibilityButton(
                obscureText: obscurePassword,
                onPressed: onTogglePassword,
              ),
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
          const SizedBox(height: AppSpacing.lg),
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
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton(
                onPressed: onForgotPassword,
                child: const Text('Quên mật khẩu'),
              ),
              TextButton(
                onPressed: onRegister,
                child: const Text('Đăng ký tài khoản'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
