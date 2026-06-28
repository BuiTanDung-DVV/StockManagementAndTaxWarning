import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _currentHasFocus = false;
  bool _newHasFocus = false;
  bool _confirmHasFocus = false;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentFocus.addListener(
      () => setState(() => _currentHasFocus = _currentFocus.hasFocus),
    );
    _newFocus.addListener(
      () => setState(() => _newHasFocus = _newFocus.hasFocus),
    );
    _confirmFocus.addListener(
      () => setState(() => _confirmHasFocus = _confirmFocus.hasFocus),
    );
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
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

  Future<void> _submitChangePassword() async {
    _error = null;
    final currentPass = _currentPasswordCtrl.text;
    final newPass = _newPasswordCtrl.text;
    final confirmPass = _confirmPasswordCtrl.text;

    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _error = 'Vui lòng điền đầy đủ các trường thông tin');
      return;
    }

    if (currentPass == newPass) {
      setState(() => _error = 'Mật khẩu mới không được trùng mật khẩu cũ');
      return;
    }

    final strengthScore = _calculatePasswordStrength(newPass);
    if (newPass.length < 8 || strengthScore < 3) {
      setState(
        () => _error =
            'Mật khẩu mới chưa đạt tiêu chuẩn bảo mật quốc tế (cần tối thiểu 8 ký tự và kết hợp chữ hoa, chữ thường, số hoặc ký tự đặc biệt)',
      );
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.put(
        '/profile/password',
        data: {'currentPassword': currentPass, 'newPassword': newPass},
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastService.showSuccess('Đổi mật khẩu tài khoản thành công!');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String msg = 'Không thể thay đổi mật khẩu. Vui lòng thử lại';
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
          'Đổi Mật Khẩu',
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
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: c.divider.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_reset_rounded,
                            size: 32,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bảo mật tài khoản',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hãy tạo mật khẩu mạnh để bảo vệ an toàn cho dữ liệu kinh doanh của bạn',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Mật khẩu hiện tại',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildGlowingField(
                    controller: _currentPasswordCtrl,
                    focusNode: _currentFocus,
                    hasFocus: _currentHasFocus,
                    hintText: 'Nhập mật khẩu đang sử dụng',
                    icon: Icons.key_rounded,
                    c: c,
                    theme: theme,
                    obscureText: _obscureCurrent,
                    onChanged: (_) => _onFieldChanged(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: c.textMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Mật khẩu mới',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildGlowingField(
                    controller: _newPasswordCtrl,
                    focusNode: _newFocus,
                    hasFocus: _newHasFocus,
                    hintText: 'Nhập mật khẩu mới',
                    icon: Icons.lock_outline_rounded,
                    c: c,
                    theme: theme,
                    obscureText: _obscureNew,
                    onChanged: (_) => _onFieldChanged(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: c.textMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  _buildPasswordStrengthMeter(c),

                  Text(
                    'Xác nhận mật khẩu mới',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildGlowingField(
                    controller: _confirmPasswordCtrl,
                    focusNode: _confirmFocus,
                    hasFocus: _confirmHasFocus,
                    hintText: 'Nhập lại mật khẩu mới',
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
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitChangePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                              'Cập Nhật Mật Khẩu',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthMeter(AppThemeColors c) {
    final pass = _newPasswordCtrl.text;
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
    final hasSpecial = pass.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>\-_+=\/\\[\]~`:]'),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
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

    final match = _newPasswordCtrl.text == confirmPass;
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
            match
                ? 'Mật khẩu xác nhận trùng khớp'
                : 'Mật khẩu xác nhận chưa khớp',
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
