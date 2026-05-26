import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/toast_service.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
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
    _phoneFocus.addListener(() => setState(() => _phoneHasFocus = _phoneFocus.hasFocus));
    _otpFocus.addListener(() => setState(() => _otpHasFocus = _otpFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordHasFocus = _passwordFocus.hasFocus));
    _confirmPasswordFocus.addListener(() => setState(() => _confirmPasswordHasFocus = _confirmPasswordFocus.hasFocus));
    
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

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Vui lòng nhập số điện thoại');
      return;
    }
    
    final phoneRegex = RegExp(r'^(0|\+84)\d{9}$');
    if (!phoneRegex.hasMatch(phone)) {
      setState(() => _error = 'Định dạng số điện thoại không hợp lệ (10 số)');
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
      
      ToastService.showSuccess('Đã gửi mã xác thực OTP thành công!');
      
      setState(() {
        _otpSent = true;
      });
      _startTimer();
    } catch (e) {
      String msg = 'Không thể gửi mã khôi phục. Vui lòng kiểm tra lại SĐT hoặc kết nối mạng';
      if (e is DioException && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
      }
      setState(() => _error = msg);
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _submitReset() async {
    final phone = _phoneCtrl.text.trim();
    final otpCode = _otpCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final confirmPass = _confirmPasswordCtrl.text;

    if (phone.isEmpty || otpCode.isEmpty || pass.isEmpty || confirmPass.isEmpty) {
      setState(() => _error = 'Vui lòng nhập đầy đủ thông tin');
      return;
    }

    if (pass != confirmPass) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    if (pass.length < 6) {
      setState(() => _error = 'Mật khẩu mới phải từ 6 ký tự trở lên');
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
        data: {
          'identifier': phone,
          'newPassword': pass,
          'otpCode': otpCode,
        },
      );

      setState(() {
        _isLoading = false;
        _success = true;
      });
      ToastService.showSuccess('Đã đặt lại mật khẩu thành công!');
    } catch (e) {
      String msg = 'Mã xác thực OTP không đúng hoặc đã hết hạn';
      if (e is DioException && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
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

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Khôi Phục Mật Khẩu',
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15), width: 1.5),
                      ),
                      child: Icon(
                        _success ? Icons.check_circle_rounded : Icons.lock_reset_rounded,
                        size: 38,
                        color: _success ? AppColors.success : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _success ? 'Đặt lại thành công!' : 'Khôi phục Mật khẩu',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _success 
                      ? 'Mật khẩu của bạn đã được thay đổi. Hãy đăng nhập lại bằng mật khẩu mới.'
                      : _otpSent 
                        ? 'Vui lòng nhập mã OTP đã gửi đến số ${_phoneCtrl.text} cùng mật khẩu mới của bạn.'
                        : 'Nhập số điện thoại đã đăng ký. Chúng tôi sẽ gửi mã xác thực OTP thật qua SMS.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_success) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Quay lại Đăng nhập',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
                        hintText: 'Nhập số điện thoại đăng ký',
                        icon: Icons.phone_android_rounded,
                        c: c,
                        theme: theme,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSendingOtp ? null : _sendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isSendingOtp
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : Text(
                                  'Gửi Mã Xác Thực OTP',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _countdownSeconds > 0 || _isSendingOtp ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: _isSendingOtp
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      _countdownSeconds > 0 ? '${_countdownSeconds}s' : 'Gửi lại',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

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
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: c.textMuted,
                            size: 20,
                          ),
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
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: c.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : Text(
                                  'Xác Nhận Đặt Lại Mật Khẩu',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: GoogleFonts.inter(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
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
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
