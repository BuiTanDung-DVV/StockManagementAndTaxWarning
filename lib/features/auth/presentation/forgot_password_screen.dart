import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/app_navigation_back_button.dart';

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

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Khôi phục mật khẩu',
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 960;
            final recoveryForm = Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: desktop ? AppSpacing.xl : AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AppCardContainer(
                    padding: EdgeInsets.all(
                      desktop ? AppSpacing.xl : AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                ),
                              ),
                              child: Icon(
                                _success
                                    ? Icons.check_circle_rounded
                                    : Icons.lock_reset_rounded,
                                size: 26,
                                color: _success
                                    ? AppColors.success
                                    : theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bước $currentStep/3',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _success
                                        ? 'Đặt lại thành công'
                                        : _otpSent
                                        ? 'Tạo mật khẩu mới'
                                        : 'Tìm tài khoản của bạn',
                                    style: GoogleFonts.manrope(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _success
                                        ? 'Mật khẩu đã được thay đổi. Hãy đăng nhập lại bằng mật khẩu mới.'
                                        : _otpSent
                                        ? 'Nếu ${_phoneCtrl.text} đã đăng ký, mã OTP sẽ được gửi tới hộp thư này.'
                                        : 'Nhập Gmail đã đăng ký để nhận hướng dẫn khôi phục tài khoản.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: c.textSecondary,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (_success) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => context.pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.control,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                'Quay lại Đăng nhập',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                ),
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
                                borderRadius: BorderRadius.circular(
                                  AppRadius.control,
                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.control,
                                    ),
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
                                    autofillHints: const [
                                      AutofillHints.oneTimeCode,
                                    ],
                                    onSubmitted: (_) =>
                                        _passwordFocus.requestFocus(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed:
                                        _countdownSeconds > 0 || _isSendingOtp
                                        ? null
                                        : _sendOtp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.control,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
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
                              onSubmitted: (_) =>
                                  _confirmPasswordFocus.requestFocus(),
                              suffixIcon: _buildPasswordVisibilityButton(
                                obscure: _obscure,
                                colors: c,
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
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
                                colors: c,
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.control,
                                    ),
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
                  ),
                ),
              ),
            );

            if (!desktop) return recoveryForm;

            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _RecoveryInfoPanel(currentStep: currentStep),
                ),
                Expanded(flex: 6, child: recoveryForm),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPasswordVisibilityButton({
    required bool obscure,
    required AppThemeColors colors,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textSecondary,
        side: BorderSide.none,
        shape: const CircleBorder(),
      ),
      icon: Icon(
        obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        size: 20,
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
        borderRadius: BorderRadius.circular(AppRadius.control),
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
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: BorderSide(color: c.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: BorderSide(color: c.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
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

class _RecoveryInfoPanel extends StatelessWidget {
  final int currentStep;

  const _RecoveryInfoPanel({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

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
                size: 52,
                semanticLabel: 'SmartStock',
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Khôi phục quyền truy cập an toàn.',
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
                'Hoàn thành ba bước để tạo mật khẩu mới và thu hồi các phiên đăng nhập cũ.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _RecoveryStep(
                index: 1,
                title: 'Xác nhận Gmail đăng ký',
                currentStep: currentStep,
                primary: primary,
              ),
              _RecoveryStep(
                index: 2,
                title: 'Nhập OTP và mật khẩu mới',
                currentStep: currentStep,
                primary: primary,
              ),
              _RecoveryStep(
                index: 3,
                title: 'Đăng nhập lại an toàn',
                currentStep: currentStep,
                primary: primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: colors.divider),
                ),
                child: Text(
                  'SmartStock không công khai Gmail có tồn tại trong hệ thống nhằm ngăn chặn dò tìm tài khoản.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryStep extends StatelessWidget {
  final int index;
  final String title;
  final int currentStep;
  final Color primary;

  const _RecoveryStep({
    required this.index,
    required this.title,
    required this.currentStep,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final active = index == currentStep;
    final completed = index < currentStep;
    final emphasized = active || completed;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: emphasized
                  ? primary.withValues(alpha: active ? 1 : 0.12)
                  : colors.card,
              shape: BoxShape.circle,
              border: Border.all(color: emphasized ? primary : colors.divider),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: active
                    ? Colors.white
                    : emphasized
                    ? primary
                    : colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: active ? colors.textPrimary : colors.textSecondary,
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
