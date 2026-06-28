import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/toast_service.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String fullName;
  final String password;
  final String accountType;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.fullName,
    required this.password,
    required this.accountType,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  bool _otpHasFocus = false;
  bool _isLoading = false;
  bool _isResending = false;
  int _countdownSeconds = 60;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _otpFocus.addListener(() {
      setState(() => _otpHasFocus = _otpFocus.hasFocus);
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _countdownSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds <= 0) {
        timer.cancel();
      } else {
        setState(() => _countdownSeconds--);
      }
    });
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isResending = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.post('/auth/send-otp', data: {'identifier': widget.email});
      ToastService.showSuccess('Đã gửi lại mã xác thực OTP tới email của bạn!');
      _startTimer();
    } catch (e) {
      String msg = 'Không thể gửi lại OTP. Vui lòng kiểm tra kết nối mạng';
      if (e is ApiException) {
        msg = e.message;
      } else if (e is DioException && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
      }
      ToastService.showError(msg);
    } finally {
      setState(() => _isResending = false);
    }
  }

  Future<void> _verifyAndRegister() async {
    final otpCode = _otpCtrl.text.trim();
    if (otpCode.isEmpty || otpCode.length < 6) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số mã OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/auth/register',
        data: {
          'username': widget.email,
          'passwordHash': widget.password,
          'fullName': widget.fullName,
          'accountType': widget.accountType,
          'otpCode': otpCode,
        },
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastService.showSuccess('Đăng ký tài khoản thành công!');
      
      // Chuyển tới màn hình đăng nhập hoặc cập nhật thông tin
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String msg = 'Xác thực OTP thất bại';
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

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Xác Thực Tài Khoản',
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nhập mã xác thực',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mã xác thực gồm 6 chữ số đã được gửi tới địa chỉ email:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _otpHasFocus
                            ? AppColors.primary
                            : (_error != null ? AppColors.danger : c.border),
                        width: _otpHasFocus ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        if (_otpHasFocus)
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: TextField(
                      controller: _otpCtrl,
                      focusNode: _otpFocus,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8.0,
                        color: c.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 24,
                          letterSpacing: 8.0,
                          color: c.textMuted,
                        ),
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                      onChanged: (val) {
                        if (val.length == 6) {
                          _verifyAndRegister();
                        }
                      },
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.danger,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyAndRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Xác nhận & Hoàn tất',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Chưa nhận được mã? ',
                        style: TextStyle(color: c.textSecondary, fontSize: 14),
                      ),
                      TextButton(
                        onPressed: (_countdownSeconds > 0 || _isResending)
                            ? null
                            : _resendOtp,
                        child: _isResending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _countdownSeconds > 0
                                    ? 'Gửi lại sau (${_countdownSeconds}s)'
                                    : 'Gửi lại mã ngay',
                                style: TextStyle(
                                  color: _countdownSeconds > 0
                                      ? c.textMuted
                                      : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
