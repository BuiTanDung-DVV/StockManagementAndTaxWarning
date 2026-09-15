import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/password_visibility_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _phoneHasFocus = false;
  bool _otpHasFocus = false;
  bool _passwordHasFocus = false;
  bool _confirmPasswordHasFocus = false;

  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;
  bool _success = false;
  int _countdownSeconds = 0;
  Timer? _timer;
  String? _error;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(
      () => setState(() => _phoneHasFocus = _phoneFocus.hasFocus),
    );
    _otpFocus.addListener(
      () => setState(() => _otpHasFocus = _otpFocus.hasFocus),
    );
    _passwordFocus.addListener(
      () => setState(() => _passwordHasFocus = _passwordFocus.hasFocus),
    );
    _confirmPasswordFocus.addListener(
      () => setState(
        () => _confirmPasswordHasFocus = _confirmPasswordFocus.hasFocus,
      ),
    );

    void clearError() {
      if (_error != null) setState(() => _error = null);
    }

    _phoneCtrl.addListener(clearError);
    _otpCtrl.addListener(clearError);
    _passwordCtrl.addListener(clearError);
    _confirmPasswordCtrl.addListener(clearError);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();

    _phoneFocus.dispose();
    _otpFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _countdownSeconds = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _countdownSeconds--);
      }
    });
  }

  void _restartWithDifferentEmail() {
    _timer?.cancel();
    _phoneCtrl.clear();
    _otpCtrl.clear();
    _passwordCtrl.clear();
    _confirmPasswordCtrl.clear();
    setState(() {
      _otpSent = false;
      _countdownSeconds = 0;
      _error = null;
      _obscure = true;
      _obscureConfirm = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim().toLowerCase();
    if (phone.isEmpty) {
      setState(() => _error = 'Vui lòng nhập địa chỉ Gmail');
      return;
    }

    final emailRegex = RegExp(r'^[^\s@]+@gmail\.com$');

    if (!emailRegex.hasMatch(phone)) {
      setState(() => _error = 'Vui lòng nhập địa chỉ @gmail.com hợp lệ');
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      // Calls forgot-password API which dynamically sends OTP
      await api.post('/auth/forgot-password', data: {'identifier': phone});

      ToastService.showSuccess(
        'Nếu Gmail đã đăng ký, hệ thống sẽ gửi mã xác thực OTP.',
      );

      setState(() {
        _otpSent = true;
      });
      _startTimer();
    } catch (e) {
      String msg =
          'Không thể gửi mã khôi phục. Vui lòng kiểm tra lại địa chỉ hoặc kết nối mạng';
      if (e is ApiException) {
        msg = e.message;
      } else if (e is DioException && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
      }
      final lowerMsg = msg.toLowerCase();
      if (lowerMsg.contains('network') ||
          lowerMsg.contains('connection') ||
          lowerMsg.contains('socket')) {
        msg = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.';
      }
      setState(() => _error = msg);
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _submitReset() async {
    final phone = _phoneCtrl.text.trim().toLowerCase();
    final otpCode = _otpCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final confirmPass = _confirmPasswordCtrl.text;

    if (phone.isEmpty ||
        otpCode.isEmpty ||
        pass.isEmpty ||
        confirmPass.isEmpty) {
      setState(() => _error = 'Vui lòng nhập đầy đủ thông tin');
      return;
    }

    if (otpCode.length != 6) {
      setState(() => _error = 'Mã xác thực OTP phải gồm 6 chữ số');
      return;
    }

    if (pass != confirmPass) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    final strongPassword =
        pass.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(pass) &&
        RegExp(r'[a-z]').hasMatch(pass) &&
        RegExp(r'\d').hasMatch(pass) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(pass);
    if (!strongPassword) {
      setState(
        () => _error =
            'Mật khẩu phải có ít nhất 8 ký tự, chữ hoa, chữ thường, số và ký tự đặc biệt',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/auth/reset-password',
        data: {'identifier': phone, 'newPassword': pass, 'otpCode': otpCode},
      );

      setState(() {
        _isLoading = false;
        _success = true;
      });
      ToastService.showSuccess('Đã đặt lại mật khẩu thành công!');
    } catch (e) {
      String msg = 'Mã xác thực OTP không đúng hoặc đã hết hạn';
      if (e is ApiException) {
        msg = e.message;
      } else if (e is DioException && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
      }
      final lowerMsg = msg.toLowerCase();
      if (lowerMsg.contains('network') ||
          lowerMsg.contains('connection') ||
          lowerMsg.contains('socket')) {
        msg = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.';
      }
      setState(() {
        _isLoading = false;
        _error = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final currentStep = _success ? 3 : (_otpSent ? 2 : 1);

    return AuthScaffold(
      canPop: true,
      onPop: () => context.canPop() ? context.pop() : context.go('/login'),
      brandHeadline: 'Khôi phục quyền truy cập an toàn.',
      brandDescription:
          'Hoàn thành ba bước để tạo mật khẩu mới và thu hồi các phiên đăng nhập cũ.',
      brandCapabilities: const [
        'Xác nhận Gmail đăng ký an toàn',
        'Nhập OTP và mật khẩu mới',
        'Đăng nhập lại an toàn',
      ],
      title: _success
          ? 'Đặt lại thành công'
          : _otpSent
          ? 'Tạo mật khẩu mới'
          : 'Tìm tài khoản của bạn',
      subtitle: _success
          ? 'Mật khẩu đã được thay đổi. Hãy đăng nhập lại bằng mật khẩu mới.'
          : _otpSent
          ? 'Nếu ${_phoneCtrl.text} đã đăng ký, mã OTP sẽ được gửi tới hộp thư này.'
          : 'Nhập Gmail đã đăng ký để nhận hướng dẫn khôi phục tài khoản.',
      footer: _success
          ? null
          : Center(
              child: TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/login'),
                child: const Text('Nhớ mật khẩu? Đăng nhập ngay'),
              ),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _success
                      ? Icons.check_circle_rounded
                      : Icons.lock_reset_rounded,
                  size: 16,
                  color: _success
                      ? AppColors.success
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Bước $currentStep/3',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (_success) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Quay lại Đăng nhập',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else ...[
            // Step 1: Input phone & send OTP
            if (!_otpSent) ...[
              _buildGlowingField(
                controller: _phoneCtrl,
                focusNode: _phoneFocus,
                hasFocus: _phoneHasFocus,
                hintText: 'Nhập địa chỉ Gmail đã đăng ký',
                icon: Icons.contact_mail_rounded,
                c: c,
                theme: theme,
                enabled: !_otpSent,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) {
                  if (!_isSendingOtp) _sendOtp();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: c.divider),
                ),
                child: Text(
                  'Vì an toàn tài khoản, hệ thống không xác nhận công khai Gmail có tồn tại. OTP chỉ được tạo và gửi khi Gmail đã đăng ký.',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSendingOtp ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  child: _isSendingOtp
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Gửi Mã Xác Thực OTP',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ] else ...[
              // Step 2: Verification and Reset password
              Row(
                children: [
                  Expanded(
                    child: _buildGlowingField(
                      controller: _otpCtrl,
                      focusNode: _otpFocus,
                      hasFocus: _otpHasFocus,
                      hintText: 'Mã xác thực OTP (6 số)',
                      icon: Icons.security_rounded,
                      c: c,
                      theme: theme,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _countdownSeconds > 0 || _isSendingOtp
                          ? null
                          : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _isSendingOtp
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _countdownSeconds > 0
                                  ? '${_countdownSeconds}s'
                                  : 'Gửi lại',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _restartWithDifferentEmail,
                  child: const Text('Dùng Gmail khác'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // New Password Input
              _buildGlowingField(
                controller: _passwordCtrl,
                focusNode: _passwordFocus,
                hasFocus: _passwordHasFocus,
                hintText: 'Mật khẩu mới',
                icon: Icons.lock_outline_rounded,
                c: c,
                theme: theme,
                obscureText: _obscure,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                suffixIcon: _buildPasswordVisibilityButton(
                  obscure: _obscure,
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 12),

              // Confirm New Password Input
              _buildGlowingField(
                controller: _confirmPasswordCtrl,
                focusNode: _confirmPasswordFocus,
                hasFocus: _confirmPasswordHasFocus,
                hintText: 'Nhập lại mật khẩu mới',
                icon: Icons.lock_outline_rounded,
                c: c,
                theme: theme,
                obscureText: _obscureConfirm,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) {
                  if (!_isLoading) _submitReset();
                },
                suffixIcon: _buildPasswordVisibilityButton(
                  obscure: _obscureConfirm,
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Mật khẩu cần ít nhất 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
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
                          'Xác Nhận Đặt Lại Mật Khẩu',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],

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
          ],
        ],
      ),
    );
  }

  Widget _buildPasswordVisibilityButton({
    required bool obscure,
    required VoidCallback onPressed,
  }) {
    return PasswordVisibilityButton(obscureText: obscure, onPressed: onPressed);
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
    bool enabled = true,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onSubmitted,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.input),
        boxShadow: [
          if (hasFocus)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: c.textMuted, size: 20),
          suffixIcon: suffixIcon,
          suffixIconConstraints: suffixIcon == null
              ? null
              : const BoxConstraints.tightFor(width: 48, height: 48),
          filled: true,
          fillColor: c.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: BorderSide(color: c.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: BorderSide(color: c.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
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
