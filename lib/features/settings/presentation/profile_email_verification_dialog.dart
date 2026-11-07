import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class ProfileEmailVerificationDialog extends ConsumerStatefulWidget {
  final String email;

  const ProfileEmailVerificationDialog({super.key, required this.email});

  @override
  ConsumerState<ProfileEmailVerificationDialog> createState() =>
      _ProfileEmailVerificationDialogState();
}

class _ProfileEmailVerificationDialogState
    extends ConsumerState<ProfileEmailVerificationDialog> {
  final _password = TextEditingController();
  final _code = TextEditingController();
  Timer? _timer;
  bool _busy = false;
  bool _sent = false;
  int _resendSeconds = 0;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy || _resendSeconds > 0) return;
    if (_password.text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mật khẩu hiện tại');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .post(
            '/profile/email-verification/request',
            data: {
              'currentPassword': _password.text,
              'expectedEmail': widget.email,
            },
          );
      if (!mounted) return;
      if (response['emailVerified'] == true) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _sent = true;
        _resendSeconds = 60;
        _code.clear();
      });
      _timer?.cancel();
      final resendAt = DateTime.now().add(const Duration(seconds: 60));
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(
          () => _resendSeconds =
              (resendAt.difference(DateTime.now()).inMilliseconds / 1000)
                  .ceil()
                  .clamp(0, 60),
        );
        if (_resendSeconds <= 0) timer.cancel();
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không thể gửi mã xác minh. Vui lòng thử lại sau.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .post(
            '/profile/email-verification/confirm',
            data: {'otpCode': _code.text, 'expectedEmail': widget.email},
          );
      if (!mounted) return;
      if (response['emailVerified'] != true) {
        throw const FormatException('Verification was not confirmed');
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Chưa thể xác minh Gmail. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Xác minh Gmail'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.email),
              const SizedBox(height: 12),
              const Text(
                'Nhập mật khẩu hiện tại để nhận mã xác minh. Thao tác này giữ nguyên Gmail và tên đăng nhập.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                ),
                onSubmitted: (_) => !_sent ? _request() : null,
              ),
              if (_sent) ...[
                const SizedBox(height: 16),
                const Text(
                  'Đã gửi mã. Mã có hiệu lực 5 phút; hãy dùng mã mới nhất.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mã xác minh 6 chữ số',
                  ),
                  onSubmitted: (_) => _confirm(),
                ),
                TextButton(
                  onPressed: _busy || _resendSeconds > 0 ? null : _request,
                  child: Text(
                    _resendSeconds > 0
                        ? 'Gửi lại sau ${_resendSeconds}s'
                        : 'Gửi lại mã',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: _busy ? null : (_sent ? _confirm : _request),
          child: Text(
            _busy ? 'Đang xử lý…' : (_sent ? 'Xác minh' : 'Gửi mã xác minh'),
          ),
        ),
      ],
    );
  }
}
