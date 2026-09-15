import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../providers/auth_provider.dart';

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
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
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
      await api.post(
        '/auth/send-otp',
        data: {
          'identifier': widget.email.toLowerCase(),
          'isRegistration': true,
        },
      );
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
    if (_isLoading) return;
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
      final success = await ref
          .read(authProvider.notifier)
          .registerWithOtp(
            email: widget.email,
            password: widget.password,
            fullName: widget.fullName,
            accountType: widget.accountType,
            otpCode: otpCode,
          );
      if (!success) {
        throw ApiException(
          ref.read(authProvider).error ?? 'Xác thực OTP thất bại',
        );
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastService.showSuccess('Đăng ký tài khoản thành công!');

      // Chuyển tới màn hình đăng nhập hoặc cập nhật thông tin
      context.go('/onboarding');
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
    return AuthScaffold(
      canPop: true,
      onPop: () => context.canPop() ? context.pop() : context.go('/register'),
      title: 'Xác thực tài khoản',
      subtitle: 'Mã OTP gồm 6 chữ số đã được gửi đến email:',
      footer: Center(
        child: TextButton.icon(
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Quay lại đăng ký / đổi email'),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/register'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: c.cardAlt,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: c.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    widget.email,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: _otpHasFocus
                    ? Theme.of(context).colorScheme.primary
                    : (_error != null ? AppColors.danger : c.inputBorder),
                width: _otpHasFocus ? 1.5 : 1.0,
              ),
              boxShadow: [
                if (_otpHasFocus)
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: TextField(
              controller: _otpCtrl,
              focusNode: _otpFocus,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 10.0,
                color: c.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '••••••',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 26,
                  letterSpacing: 10.0,
                  color: c.textMuted,
                ),
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              onChanged: (val) {
                if (val.length == 6 && !_isLoading) {
                  _verifyAndRegister();
                }
              },
            ),
          ),
          if (_error != null) ...[
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
                    color: AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _error!,
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
            onPressed: _isLoading ? null : _verifyAndRegister,
            child: _isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Xác nhận & Hoàn tất'),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Chưa nhận được mã? ',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              TextButton(
                onPressed: (_countdownSeconds > 0 || _isResending)
                    ? null
                    : _resendOtp,
                child: Text(
                  _countdownSeconds > 0
                      ? 'Gửi lại (${_countdownSeconds}s)'
                      : (_isResending ? 'Đang gửi...' : 'Gửi lại mã OTP'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _countdownSeconds > 0
                        ? c.textMuted
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
