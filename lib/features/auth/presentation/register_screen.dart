import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';

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
  String _accountType = 'SHOP';

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
    if (pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>\-_+=\/\\[\]~`:]'))) score++;
    return score;
  }

  Future<void> _handleSocialRegister(String provider) async {
    ToastService.showSuccess('Đang xác thực qua $provider...');
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      context.go('/onboarding');
    });
  }

  Future<void> _proceedToOtpVerification() async {
    _error = null;
    final fullName = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final confirmPass = _confirmPasswordCtrl.text;

    if (fullName.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Vui lòng điền đầy đủ thông tin');
      return;
    }

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Địa chỉ Email không hợp lệ');
      return;
    }

    final strengthScore = _calculatePasswordStrength(pass);
    if (pass.length < 8 || strengthScore < 3) {
      setState(() => _error = 'Mật khẩu chưa đạt tiêu chuẩn bảo quốc tế (cần tối thiểu 8 ký tự kết hợp chữ hoa, chữ thường, số hoặc ký tự đặc biệt)');
      return;
    }

    if (pass != confirmPass) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.post('/auth/send-otp', data: {'identifier': email});

      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastService.showSuccess('Đã gửi mã xác thực về email của bạn!');

      context.push(
        '/verify-otp',
        extra: {
          'email': email,
          'fullName': fullName,
          'password': pass,
          'accountType': _accountType,
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
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewportConstraints.maxHeight - 32,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tạo tài khoản mới',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _accountType == 'SHOP'
                                ? 'để bắt đầu quản lý bán hàng & kho hàng doanh nghiệp'
                                : 'để xin gia nhập và làm việc tại cửa hàng',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Social Registration Options
                          Row(
                            children: [
                              Expanded(
                                child: _buildSocialButton(
                                  icon: Icons.g_mobiledata_rounded,
                                  iconColor: Colors.redAccent,
                                  label: 'Google',
                                  onTap: () => _handleSocialRegister('Google'),
                                  c: c,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSocialButton(
                                  icon: Icons.facebook_rounded,
                                  iconColor: Colors.blueAccent,
                                  label: 'Facebook',
                                  onTap: () => _handleSocialRegister('Facebook'),
                                  c: c,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: Divider(color: c.divider)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'HOẶC ĐĂNG KÝ BẰNG EMAIL',
                                  style: GoogleFonts.outfit(
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

                          // Account Type Selection
                          SegmentedButton<String>(
                            segments: [
                              ButtonSegment<String>(
                                value: 'SHOP',
                                label: Text(
                                  'Chủ cửa hàng',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                icon: const Icon(Icons.store_rounded, size: 18),
                              ),
                              ButtonSegment<String>(
                                value: 'PERSONAL',
                                label: Text(
                                  'Nhân viên',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                ),
                              ),
                            ],
                            selected: {_accountType},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _accountType = newSelection.first;
                              });
                            },
                            style: SegmentedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
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
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: c.textMuted,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
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
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: c.textMuted,
                                size: 20,
                              ),
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
                              onPressed: _isLoading ? null : _proceedToOtpVerification,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
                                      style: GoogleFonts.outfit(
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
                    ),
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

    final hasLen = pass.length >= 8;
    final hasUpper = pass.contains(RegExp(r'[A-Z]'));
    final hasLower = pass.contains(RegExp(r'[a-z]'));
    final hasDigit = pass.contains(RegExp(r'[0-9]'));
    final hasSpecial = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>\-_+=\/\\[\]~`:]'));

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (index) {
              final active = index < score;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: active ? color : c.divider,
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
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildCriteriaItem('Từ 8 ký tự', hasLen, c),
              _buildCriteriaItem('Chữ hoa (A-Z)', hasUpper, c),
              _buildCriteriaItem('Chữ thường (a-z)', hasLower, c),
              _buildCriteriaItem('Chữ số (0-9)', hasDigit, c),
              _buildCriteriaItem('Ký tự đặc biệt', hasSpecial, c),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildCriteriaItem(String text, bool met, AppThemeColors c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 14,
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
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          Icon(
            match ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 15,
            color: match ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 6),
          Text(
            match ? 'Mật khẩu xác nhận trùng khớp' : 'Mật khẩu xác nhận chưa khớp',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: match ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    required AppThemeColors c,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
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
