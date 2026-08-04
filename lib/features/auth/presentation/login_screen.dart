import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/app_version_widget.dart';
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
        .authenticateWithGoogle(idToken: idToken, createIfMissing: true);
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
    final colors = AppThemeColors.of(context);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;
            final form = _LoginForm(
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
            );

            if (!desktop) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        const _CompactBrandHeader(),
                        const SizedBox(height: AppSpacing.lg),
                        form,
                      ],
                    ),
                  ),
                ),
              );
            }

            return Row(
              children: [
                const Expanded(flex: 5, child: _DesktopBrandPanel()),
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: form,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompactBrandHeader extends StatelessWidget {
  const _CompactBrandHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppAssetIcon(
          assetPath: AppAssets.appIcon,
          size: 42,
          semanticLabel: 'SmartStock',
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SmartStock POS & Tax',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Bán hàng, Kho & Cảnh báo thuế HKD',
              style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
            ),
          ],
        ),
      ],
    );
  }
}

class _DesktopBrandPanel extends StatelessWidget {
  const _DesktopBrandPanel();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppAssetIcon(
                assetPath: AppAssets.appIcon,
                size: 56,
                semanticLabel: 'SmartStock',
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Vận hành cửa hàng trên một hệ thống thống nhất.',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 30,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Theo dõi bán hàng, tồn kho, dòng tiền và các cảnh báo nghiệp vụ cần xử lý.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _BrandCapability(index: '01', title: 'Bán hàng và công nợ'),
              const _BrandCapability(
                index: '02',
                title: 'Nhập xuất tồn và giá vốn',
              ),
              const _BrandCapability(
                index: '03',
                title: 'Tài chính và hỗ trợ cảnh báo thuế',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandCapability extends StatelessWidget {
  final String index;
  final String title;

  const _BrandCapability({required this.index, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              index,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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

    return AppCardContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Đăng nhập',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nhập thông tin tài khoản để tiếp tục làm việc.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: usernameController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onSubmitted: (_) => passwordFocus.requestFocus(),
              decoration: const InputDecoration(
                labelText: 'Gmail hoặc tên đăng nhập',
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
                suffixIcon: TextButton(
                  onPressed: onTogglePassword,
                  child: Text(obscurePassword ? 'Hiện' : 'Ẩn'),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: loading ? null : onLogin,
              child: loading
                  ? const SizedBox.square(
                      dimension: 18,
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
            const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.lg),
            const Center(child: AppVersionWidget()),
          ],
        ),
      ),
    );
  }
}
