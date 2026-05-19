import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _fullNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;
  String _accountType = 'SHOP';

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _fullNameFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    final fullName = _fullNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final confirmPass = _confirmPasswordCtrl.text;

    if (fullName.isEmpty || phone.isEmpty || pass.isEmpty) {
      setState(() {
        _error = 'Vui lòng điền đầy đủ thông tin';
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
      // Backend expects fields based on TypeORM entity in backend/src/auth/entities.ts:
      // { username, passwordHash, fullName }
      await api.post(
        '/auth/register',
        data: {
          'username': phone,
          'passwordHash': pass,
          'fullName': fullName,
          'accountType': _accountType,
        },
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng ký thành công! Vui lòng đăng nhập.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'Đăng ký không thành công. Vui lòng thử lại.';
      if (e is DioException && e.error is ApiException) {
        errorMessage = (e.error as ApiException).message;
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Đăng ký tài khoản'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewportConstraints.maxHeight - 64,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tạo tài khoản mới',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                      _accountType == 'SHOP'
                          ? 'để bắt đầu quản lý bán hàng & kho hàng'
                          : 'để tham gia hệ thống với tư cách nhân viên',
                      style: TextStyle(
                          fontSize: 14, color: c.textSecondary)),
                  SizedBox(height: 24),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'SHOP',
                        label: Text('Chủ cửa hàng'),
                        icon: Icon(Icons.store),
                      ),
                      ButtonSegment<String>(
                        value: 'PERSONAL',
                        label: Text('Nhân viên'),
                        icon: Icon(Icons.person),
                      ),
                    ],
                    selected: {_accountType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _accountType = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _fullNameCtrl,
                    focusNode: _fullNameFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _phoneFocus.requestFocus(),
                    decoration: InputDecoration(
                      hintText: 'Họ và tên của bạn',
                      prefixIcon: Icon(Icons.badge, color: c.textMuted),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _phoneCtrl,
                    focusNode: _phoneFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    decoration: InputDecoration(
                      hintText: 'SĐT hoặc Tên đăng nhập',
                      prefixIcon: Icon(Icons.account_circle,
                          color: c.textMuted),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _passwordCtrl,
                    focusNode: _passwordFocus,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                    decoration: InputDecoration(
                      hintText: 'Mật khẩu',
                      prefixIcon: Icon(Icons.lock_outline,
                          color: c.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: c.textMuted),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordCtrl,
                    focusNode: _confirmPasswordFocus,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _register(),
                    decoration: InputDecoration(
                      hintText: 'Xác nhận mật khẩu',
                      prefixIcon: Icon(Icons.lock_outline,
                          color: c.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: c.textMuted),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
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
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Đăng ký'),
                  ),
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
}
