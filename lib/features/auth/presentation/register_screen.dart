import 'dart:async';
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
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  
  final _fullNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _fullNameHasFocus = false;
  bool _phoneHasFocus = false;
  bool _otpHasFocus = false;
  bool _passwordHasFocus = false;
  bool _confirmPasswordHasFocus = false;

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isSendingOtp = false;
  int _countdownSeconds = 0;
  Timer? _timer;
  String? _error;
  String _accountType = 'SHOP';

  @override
  void initState() {
    super.initState();
    _fullNameFocus.addListener(() => setState(() => _fullNameHasFocus = _fullNameFocus.hasFocus));
    _phoneFocus.addListener(() => setState(() => _phoneHasFocus = _phoneFocus.hasFocus));
    _otpFocus.addListener(() => setState(() => _otpHasFocus = _otpFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordHasFocus = _passwordFocus.hasFocus));
    _confirmPasswordFocus.addListener(() => setState(() => _confirmPasswordHasFocus = _confirmPasswordFocus.hasFocus));
    
    void clearError() {
      if (_error != null) setState(() => _error = null);
    }
    _fullNameCtrl.addListener(clearError);
    _phoneCtrl.addListener(clearError);
    _otpCtrl.addListener(clearError);
    _passwordCtrl.addListener(clearError);
    _confirmPasswordCtrl.addListener(clearError);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    
    _fullNameFocus.dispose();
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
      ToastService.showError('Vui lòng nhập số điện thoại để nhận mã OTP');
      return;
    }
    
    final phoneRegex = RegExp(r'^(0|\+84)\d{8,11}$');
    if (!phoneRegex.hasMatch(phone)) {
      ToastService.showError('Định dạng số điện thoại không hợp lệ (10-12 số)');
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/auth/send-otp', data: {'phone': phone});
      
      if (res.data != null && res.data['otp'] != null) {
        final mockOtp = res.data['otp'];
        ToastService.showSuccess('[SANDBOX] Mã OTP của bạn là: $mockOtp');
      } else {
        ToastService.showSuccess('Đã gửi mã OTP thành công về số điện thoại của bạn!');
      }
      
      _startTimer();
    } catch (e) {
      String msg = 'Không thể gửi OTP. Vui lòng kiểm tra kết nối mạng';
      if (e is DioException && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
      }
      ToastService.showError(msg);
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _register() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    final fullName = _fullNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final otpCode = _otpCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final confirmPass = _confirmPasswordCtrl.text;

    if (fullName.isEmpty || phone.isEmpty || pass.isEmpty || otpCode.isEmpty) {
      setState(() {
        _error = 'Vui lòng điền đầy đủ thông tin và mã OTP';
        _isLoading = false;
      });
      return;
    }

    if (pass != confirmPass) {
      setState(() {
        _error = 'Mật khẩu xác nhận không khớp';
        _isLoading = false;
      });
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/auth/register',
        data: {
          'username': phone,
          'passwordHash': pass,
          'fullName': fullName,
          'accountType': _accountType,
          'otpCode': otpCode,
        },
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastService.showSuccess('Đăng ký tài khoản thành công! Vui lòng đăng nhập.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'Đăng ký không thành công. Vui lòng thử lại.';
      if (e is DioException && e.error is ApiException) {
        errorMessage = (e.error as ApiException).message;
      }
      final lowerMsg = errorMessage.toLowerCase();
      if (lowerMsg.contains('already exists') || lowerMsg.contains('đã tồn tại')) {
        errorMessage = 'Tên đăng nhập hoặc số điện thoại này đã được sử dụng. Vui lòng thử số khác.';
      } else if (lowerMsg.contains('network') || lowerMsg.contains('connection') || lowerMsg.contains('socket')) {
        errorMessage = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.';
      }
      setState(() {
        _isLoading = false;
        _error = errorMessage;
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                                : 'để tham gia hệ thống kinh doanh với vai trò nhân viên',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Elegant Segmented Select Button
                          SegmentedButton<String>(
                            segments: [
                              ButtonSegment<String>(
                                value: 'SHOP',
                                label: Text('Chủ cửa hàng', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                icon: const Icon(Icons.store_rounded, size: 18),
                              ),
                              ButtonSegment<String>(
                                value: 'PERSONAL',
                                label: Text('Nhân viên', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                icon: const Icon(Icons.person_rounded, size: 18),
                              ),
                            ],
                            selected: {_accountType},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _accountType = newSelection.first;
                              });
                            },
                            style: SegmentedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          ),
                          const SizedBox(height: 12),

                          // Phone/Username Input
                          Row(
                            children: [
                              Expanded(
                                child: _buildGlowingField(
                                  controller: _phoneCtrl,
                                  focusNode: _phoneFocus,
                                  hasFocus: _phoneHasFocus,
                                  hintText: 'Số điện thoại đăng ký',
                                  icon: Icons.phone_android_rounded,
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
                                          _countdownSeconds > 0 ? '${_countdownSeconds}s' : 'Gửi mã',
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // OTP Input
                          _buildGlowingField(
                            controller: _otpCtrl,
                            focusNode: _otpFocus,
                            hasFocus: _otpHasFocus,
                            hintText: 'Mã xác thực OTP (6 chữ số)',
                            icon: Icons.security_rounded,
                            c: c,
                            theme: theme,
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
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: c.textMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),

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
                          const SizedBox(height: 28),

                          // Submit Action
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
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
                                      'Đăng Ký Thành Viên',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
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
