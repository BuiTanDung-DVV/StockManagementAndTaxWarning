import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _isLoading = true;
      _success = false;
    });

    final phone = _phoneCtrl.text.trim();

    if (phone.isEmpty) {
      setState(() {
        _error = 'Vui lòng nhập số điện thoại hoặc email';
        _isLoading = false;
      });
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/auth/forgot-password',
        data: {'identifier': phone},
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Chức năng quên mật khẩu chưa sẵn sàng hoặc không kết nối được máy chủ.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Quên mật khẩu'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, size: 64, color: AppColors.primary),
                  const SizedBox(height: 24),
                  Text('Khôi phục mật khẩu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text(
                      'Nhập số điện thoại hoặc email đã đăng ký. Hệ thống sẽ gửi hướng dẫn khôi phục mật khẩu cho bạn.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: c.textSecondary)),
                  const SizedBox(height: 32),
                  if (_success) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.success, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Yêu cầu thành công!',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Vui lòng kiểm tra điện thoại/email để nhận thông tin khôi phục mật khẩu cho tài khoản ${_phoneCtrl.text}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => context.pop(),
                            child: Text('Quay lại Đăng nhập'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _phoneCtrl,
                      decoration: InputDecoration(
                        hintText: 'Nhập số điện thoại/Email',
                        prefixIcon: Icon(Icons.contact_mail,
                            color: c.textMuted),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: AppColors.danger, fontSize: 13))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Xác nhận'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
