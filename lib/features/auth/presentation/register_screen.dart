import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../../../core/widgets/password_visibility_button.dart';
import '../../settings/providers/shop_provider.dart';
import '../providers/auth_provider.dart';
import 'widgets/google_sign_in_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _fullNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _fullNameHasFocus = false;
  bool _emailHasFocus = false;
  bool _passwordHasFocus = false;
  bool _confirmPasswordHasFocus = false;

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;
  final String _registrationAccountType = 'PERSONAL';

  @override
  void initState() {
    super.initState();
    _fullNameFocus.addListener(
      () => setState(() => _fullNameHasFocus = _fullNameFocus.hasFocus),
    );
    _emailFocus.addListener(
      () => setState(() => _emailHasFocus = _emailFocus.hasFocus),
    );
    _passwordFocus.addListener(
      () => setState(() => _passwordHasFocus = _passwordFocus.hasFocus),
    );
    _confirmPasswordFocus.addListener(
      () => setState(
        () => _confirmPasswordHasFocus = _confirmPasswordFocus.hasFocus,
      ),
    );
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();

    _fullNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_error != null) {
      setState(() => _error = null);
    } else {
      setState(() {});
    }
  }

  int _calculatePasswordStrength(String pass) {
    if (pass.isEmpty) return 0;
    int score = 0;
    if (pass.length >= 8) score++;
    if (pass.contains(RegExp(r'[A-Z]'))) score++;
    if (pass.contains(RegExp(r'[a-z]'))) score++;
    if (pass.contains(RegExp(r'[0-9]'))) score++;
    if (pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>\-_+=\/\\[\]~`:]'))) {
      score++;
    }
    return score;
  }

  bool get _canSubmit {
    final email = _emailCtrl.text.trim().toLowerCase();
    return _fullNameCtrl.text.trim().length >= 2 &&
        RegExp(r'^[^\s@]+@gmail\.com$').hasMatch(email) &&
        _calculatePasswordStrength(_passwordCtrl.text) == 5 &&
        _passwordCtrl.text == _confirmPasswordCtrl.text;
  }

  Future<void> _registerWithGoogle(String idToken) async {
    setState(() => _isLoading = true);
    final success = await ref
        .read(authProvider.notifier)
        .authenticateWithGoogle(
          idToken: idToken,
          createIfMissing: true,
          accountType: _registrationAccountType,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      ToastService.showSuccess('Xác thực Google thành công!');
      final auth = ref.read(authProvider);
      if (!auth.isOnboarded) {
        context.go('/onboarding');
      } else {
        final shopState = ref.read(shopProvider);
        context.go(shopState.isPending ? '/waiting-approval' : '/');
      }
    } else {
      final message = ref.read(authProvider).error;
      if (message != null) {
        setState(() => _error = message);
        ToastService.showError(message);
      }
    }
  }

  Future<void> _proceedToOtpVerification() async {
    _error = null;
    final fullName = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passwordCtrl.text;
    final confirmPass = _confirmPasswordCtrl.text;

    if (fullName.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Vui lòng điền đầy đủ thông tin');
      return;
    }

    final emailRegex = RegExp(r'^[^\s@]+@gmail\.com$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Vui lòng sử dụng địa chỉ @gmail.com hợp lệ');
      return;
    }

    final strengthScore = _calculatePasswordStrength(pass);
    if (pass.length < 8 || strengthScore < 5) {
      setState(
        () => _error =
            'Mật khẩu phải có ít nhất 8 ký tự, chữ hoa, chữ thường, số và ký tự đặc biệt',
      );
      return;
    }

    if (pass != confirmPass) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/auth/send-otp',
        data: {'identifier': email, 'isRegistration': true},
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastService.showSuccess('Đã gửi mã xác thực về email của bạn!');

      context.push(
        '/verify-otp',
        extra: {
          'email': email,
          'fullName': fullName,
          'password': pass,
          'accountType': _registrationAccountType,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String msg = 'Không thể gửi mã OTP. Vui lòng kiểm tra lại kết nối';
      if (e is ApiException) {
        msg = e.message;
      } else if (e is DioException && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
      }
      setState(() => _error = msg);
      ToastService.showError(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Đăng Ký Tài Khoản',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(onPressed: context.pop)
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: LayoutBuilder(
              builder: (context, viewportConstraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tạo tài khoản mới',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Vai trò và thông tin cửa hàng sẽ được thiết lập ở bước tiếp theo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 24),

                      GoogleAuthButton(
                        enabled: !_isLoading,
                        isRegistration: true,
                        onIdToken: _registerWithGoogle,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(child: Divider(color: c.divider)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'HOẶC ĐĂNG KÝ BẰNG EMAIL',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: c.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: c.divider)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Full Name Input
                      _buildGlowingField(
                        controller: _fullNameCtrl,
                        focusNode: _fullNameFocus,
                        hasFocus: _fullNameHasFocus,
                        hintText: 'Họ và tên của bạn',
                        icon: Icons.person_outline_rounded,
                        c: c,
                        theme: theme,
                        onChanged: (_) => _onFieldChanged(),
                      ),
                      const SizedBox(height: 12),

                      // Email Input
                      _buildGlowingField(
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        hasFocus: _emailHasFocus,
                        hintText: 'Địa chỉ Email (Gmail)',
                        icon: Icons.email_outlined,
                        c: c,
                        theme: theme,
                        onChanged: (_) => _onFieldChanged(),
                      ),
                      const SizedBox(height: 12),

                      // Password Input
                      _buildGlowingField(
                        controller: _passwordCtrl,
                        focusNode: _passwordFocus,
                        hasFocus: _passwordHasFocus,
                        hintText: 'Mật khẩu',
                        icon: Icons.lock_outline_rounded,
                        c: c,
                        theme: theme,
                        obscureText: _obscure,
                        onChanged: (_) => _onFieldChanged(),
                        suffixIcon: PasswordVisibilityButton(
                          obscureText: _obscure,
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      _buildPasswordStrengthMeter(c),

                      // Confirm Password Input
                      _buildGlowingField(
                        controller: _confirmPasswordCtrl,
                        focusNode: _confirmPasswordFocus,
                        hasFocus: _confirmPasswordHasFocus,
                        hintText: 'Xác nhận mật khẩu',
                        icon: Icons.lock_clock_outlined,
                        c: c,
                        theme: theme,
                        obscureText: _obscureConfirm,
                        onChanged: (_) => _onFieldChanged(),
                        suffixIcon: PasswordVisibilityButton(
                          obscureText: _obscureConfirm,
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                      _buildConfirmPasswordMatchIndicator(c),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: GoogleFonts.inter(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // Submit Action
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading || !_canSubmit
                              ? null
                              : _proceedToOtpVerification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Đăng Ký & Nhận Mã OTP',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthMeter(AppThemeColors c) {
    final pass = _passwordCtrl.text;
    if (pass.isEmpty) return const SizedBox.shrink();

    final score = _calculatePasswordStrength(pass);
    Color color;
    String label;
    if (score <= 2) {
      color = AppColors.danger;
      label = 'Yếu';
    } else if (score == 3) {
      color = AppColors.warning;
      label = 'Trung bình';
    } else if (score == 4) {
      color = AppColors.info;
      label = 'Mạnh';
    } else {
      color = AppColors.success;
      label = 'Cực mạnh';
    }

    final isFocused = _passwordFocus.hasFocus;
    final isStrongEnough = score >= 4;

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (index) {
              final active = index < (score >= 4 ? 4 : score);
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 3,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: active ? color : c.divider.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Độ mạnh mật khẩu:',
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          if (isFocused && !isStrongEnough) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildCriteriaItem('Từ 8 ký tự', pass.length >= 8, c),
                _buildCriteriaItem(
                  'Chữ hoa (A-Z)',
                  pass.contains(RegExp(r'[A-Z]')),
                  c,
                ),
                _buildCriteriaItem(
                  'Chữ thường (a-z)',
                  pass.contains(RegExp(r'[a-z]')),
                  c,
                ),
                _buildCriteriaItem(
                  'Chữ số (0-9)',
                  pass.contains(RegExp(r'[0-9]')),
                  c,
                ),
                _buildCriteriaItem(
                  'Ký tự đặc biệt',
                  pass.contains(
                    RegExp(r'[!@#$%^&*(),.?":{}|<>\-_+=\/\\[\]~`:]'),
                  ),
                  c,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriteriaItem(String text, bool met, AppThemeColors c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 13,
          color: met ? AppColors.success : c.textMuted,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: met ? c.textPrimary : c.textMuted,
            fontWeight: met ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordMatchIndicator(AppThemeColors c) {
    final confirmPass = _confirmPasswordCtrl.text;
    if (confirmPass.isEmpty) return const SizedBox.shrink();

    final match = _passwordCtrl.text == confirmPass;
    if (match) {
      return const SizedBox.shrink(); // Silent success when passwords match
    }

    return const Padding(
      padding: EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.cancel_rounded, size: 14, color: AppColors.danger),
          SizedBox(width: 6),
          Text(
            'Mật khẩu xác nhận chưa khớp',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool hasFocus,
    required String hintText,
    required IconData icon,
    required AppThemeColors c,
    required ThemeData theme,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (hasFocus)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: c.textMuted, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: c.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: c.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: c.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
