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
    final currentStepText = _success
        ? 'Bước 3/3 · Hoàn tất'
        : (_otpSent
              ? 'Bước 2/3 · Xác thực và đặt mật khẩu'
              : 'Bước 1/3 · Nhập Gmail');

    return AuthScaffold(
      canPop: true,
      onPop: () => context.canPop() ? context.pop() : context.go('/login'),
      compactAuthLayout: true,
      brandHeadline: 'Khôi phục mật khẩu.',
      brandDescription: 'Thực hiện ba bước đơn giản để tạo mật khẩu mới.',
      brandCapabilities: const [
        'Xác thực qua Gmail và OTP',
        'Nhập OTP và mật khẩu mới',
        'Đăng nhập lại an toàn',
      ],
      title: _success
          ? 'Đặt lại thành công'
          : _otpSent
          ? 'Tạo mật khẩu mới'
          : 'Quên mật khẩu?',
      subtitle: _success
          ? 'Mật khẩu đã được thay đổi. Hãy đăng nhập lại bằng mật khẩu mới.'
          : _otpSent
          ? 'Nếu ${_phoneCtrl.text} đã đăng ký, mã OTP sẽ được gửi tới hộp thư này.'
          : 'Nhập Gmail để nhận mã xác thực.',
      footer: _success
          ? null
          : Center(
              child: TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/login'),
                child: const Text('Quay lại đăng nhập'),
              ),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Builder(
              builder: (context) {
                final primaryColor = Theme.of(context).colorScheme.primary;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _success
                        ? AppColors.success.withValues(alpha: 0.08)
                        : primaryColor.withValues(alpha: 0.08),
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
                        color: _success ? AppColors.success : primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          currentStepText,
                          style: TextStyle(
                            color: _success ? AppColors.success : primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_success) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/login'),
                child: const Text('Quay lại Đăng nhập'),
              ),
            ),
          ] else ...[
            // Step 1: Input phone & send OTP
            if (!_otpSent) ...[
              TextField(
                controller: _phoneCtrl,
                focusNode: _phoneFocus,
                enabled: !_otpSent,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) {
                  if (!_isSendingOtp) _sendOtp();
                },
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ Gmail',
                  hintText: 'Nhập Gmail đã đăng ký',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Nếu Gmail đã được đăng ký, bạn sẽ nhận được mã xác thực.',
                style: TextStyle(color: c.textMuted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSendingOtp ? null : _sendOtp,
                  child: _isSendingOtp
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Gửi mã xác thực'),
                ),
              ),
            ] else ...[
              // Step 2: Verification and Reset password
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _otpCtrl,
                      focusNode: _otpFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Mã xác thực OTP',
                        hintText: 'Nhập 6 số',
                        prefixIcon: Icon(Icons.security_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52, // match typical text field height
                    child: OutlinedButton(
                      onPressed: _countdownSeconds > 0 || _isSendingOtp
                          ? null
                          : _sendOtp,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _isSendingOtp
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _countdownSeconds > 0
                                  ? '${_countdownSeconds}s'
                                  : 'Gửi lại',
                            ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _restartWithDifferentEmail,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Dùng Gmail khác'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // New Password Input
              TextField(
                controller: _passwordCtrl,
                focusNode: _passwordFocus,
                obscureText: _obscure,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  hintText: 'Nhập mật khẩu mới',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: PasswordVisibilityButton(
                    obscureText: _obscure,
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Confirm New Password Input
              TextField(
                controller: _confirmPasswordCtrl,
                focusNode: _confirmPasswordFocus,
                obscureText: _obscureConfirm,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) {
                  if (!_isLoading) _submitReset();
                },
                decoration: InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                  hintText: 'Nhập lại mật khẩu mới',
                  prefixIcon: const Icon(Icons.lock_clock_outlined),
                  suffixIcon: PasswordVisibilityButton(
                    obscureText: _obscureConfirm,
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Mật khẩu cần ít nhất 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',
                style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submitReset,
                  child: _isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Xác nhận đặt lại mật khẩu'),
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
}
