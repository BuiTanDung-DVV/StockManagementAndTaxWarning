import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/widgets/google_sign_in_button.dart';

typedef ProfileGoogleButtonBuilder =
    Widget Function(
      Key key,
      bool enabled,
      Future<void> Function(String) onIdToken,
    );

final profileGoogleButtonBuilderProvider = Provider<ProfileGoogleButtonBuilder>(
  (ref) =>
      (key, enabled, onIdToken) =>
          GoogleAuthButton(key: key, enabled: enabled, onIdToken: onIdToken),
);

class ProfileEmailChangeDialog extends ConsumerStatefulWidget {
  final String currentEmail;
  final bool hasPassword;
  final bool googleLinked;

  const ProfileEmailChangeDialog({
    super.key,
    required this.currentEmail,
    required this.hasPassword,
    required this.googleLinked,
  });

  @override
  ConsumerState<ProfileEmailChangeDialog> createState() =>
      _ProfileEmailChangeDialogState();
}

class _ProfileEmailChangeDialogState
    extends ConsumerState<ProfileEmailChangeDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _oldCode = TextEditingController();
  final _newCode = TextEditingController();
  String? _currentGoogleToken, _newGoogleToken, _operationToken, _error;
  bool _busy = false, _needsNewCode = true;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _password.dispose();
    _oldCode.dispose();
    _newCode.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    final until = DateTime.now().add(const Duration(seconds: 60));
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(
        () => _resendSeconds =
            (until.difference(DateTime.now()).inMilliseconds / 1000)
                .ceil()
                .clamp(0, 60),
      );
      if (_resendSeconds == 0) timer.cancel();
    });
  }

  Future<void> _request() async {
    if (_busy || _resendSeconds > 0) return;
    final newEmail = _email.text.trim().toLowerCase();
    String? invalid;
    if (!RegExp(r'^[^\s@]+@gmail\.com$').hasMatch(newEmail)) {
      invalid = 'Vui lòng nhập Gmail mới hợp lệ';
    } else if (newEmail == widget.currentEmail.trim().toLowerCase()) {
      invalid = 'Gmail mới phải khác Gmail hiện tại';
    } else if (widget.hasPassword && _password.text.isEmpty) {
      invalid = 'Vui lòng nhập mật khẩu hiện tại';
    } else if (!widget.hasPassword && _currentGoogleToken == null) {
      invalid = 'Cần đăng nhập Google hiện đang liên kết trước';
    } else if (widget.googleLinked && _newGoogleToken == null) {
      invalid = 'Cần chọn tài khoản Google ứng với Gmail mới';
    }
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _operationToken = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .post(
            '/profile/email-change/request',
            data: {
              'expectedEmail': widget.currentEmail,
              'newEmail': newEmail,
              if (widget.hasPassword) 'currentPassword': _password.text,
              if (!widget.hasPassword)
                'currentGoogleIdToken': _currentGoogleToken,
              if (widget.googleLinked) 'newGoogleIdToken': _newGoogleToken,
            },
          );
      if (!mounted) return;
      if (response['operationToken'] is! String ||
          response['requiresNewEmailCode'] is! bool) {
        throw const FormatException('Missing email change confirmation');
      }
      setState(() {
        _operationToken = response['operationToken'];
        _needsNewCode = response['requiresNewEmailCode'];
        _oldCode.clear();
        _newCode.clear();
        _startCooldown();
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Chưa thể gửi yêu cầu đổi Gmail. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _operationToken == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_oldCode.text) ||
        (_needsNewCode && !RegExp(r'^\d{6}$').hasMatch(_newCode.text))) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số cho từng mã xác nhận');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = Map<String, dynamic>.from(
        await ref
            .read(apiClientProvider)
            .post(
              '/profile/email-change/confirm',
              data: {
                'operationToken': _operationToken,
                'currentEmailCode': _oldCode.text,
                if (_needsNewCode) 'newEmailCode': _newCode.text,
              },
            ),
      );
      if (!mounted) return;
      if (response['emailVerified'] != true ||
          response['reauthenticationRequired'] != true ||
          response['email'] != _email.text.trim().toLowerCase()) {
        throw const FormatException('Email change was not confirmed');
      }
      Navigator.of(context).pop(response);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Chưa nhận được kết quả. Nếu đã xác nhận nhưng mất kết nối, hãy thử đăng nhập bằng Gmail mới.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _codeField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) {
    final confirming = _operationToken != null;
    final googleButton = ref.watch(profileGoogleButtonBuilderProvider);
    return PopScope<Map<String, dynamic>>(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Đổi Gmail đăng nhập'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gmail hiện tại: ${widget.currentEmail}'),
                const SizedBox(height: 12),
                Text(
                  widget.googleLinked
                      ? 'Chuyển cả Gmail đăng nhập, khôi phục và liên kết Google sang Gmail mới. Dữ liệu và quyền cửa hàng được giữ nguyên.'
                      : 'Đổi Gmail đăng nhập và khôi phục. Tên đăng nhập riêng, dữ liệu và quyền cửa hàng được giữ nguyên.',
                ),
                const SizedBox(height: 16),
                if (!confirming) ...[
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Gmail mới'),
                    onChanged: (_) => setState(() => _newGoogleToken = null),
                  ),
                  const SizedBox(height: 16),
                  if (widget.hasPassword)
                    TextField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu hiện tại',
                      ),
                    ),
                  if (!widget.hasPassword && _currentGoogleToken == null) ...[
                    const Text(
                      'Bước 1: đăng nhập lại Google hiện đang liên kết.',
                    ),
                    googleButton(
                      const ValueKey('profile-google-current'),
                      !_busy,
                      (token) async {
                        if (mounted) {
                          setState(() {
                            _currentGoogleToken = token;
                            _error = null;
                          });
                        }
                      },
                    ),
                  ],
                  if (widget.googleLinked &&
                      (widget.hasPassword || _currentGoogleToken != null)) ...[
                    const SizedBox(height: 12),
                    const Text('Chọn Google ứng với Gmail mới đã nhập.'),
                    if (_newGoogleToken == null)
                      googleButton(
                        const ValueKey('profile-google-new'),
                        !_busy,
                        (token) async {
                          if (mounted) {
                            setState(() {
                              _newGoogleToken = token;
                              _error = null;
                            });
                          }
                        },
                      )
                    else
                      const Text(
                        'Đã nhận thông tin Google mới; hệ thống sẽ kiểm tra khi gửi yêu cầu.',
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _currentGoogleToken = null;
                              _newGoogleToken = null;
                            }),
                      child: const Text('Chọn lại tài khoản Google'),
                    ),
                  ],
                ] else ...[
                  Text('Gmail mới: ${_email.text.trim().toLowerCase()}'),
                  const SizedBox(height: 12),
                  const Text(
                    'Mã có hiệu lực 5 phút. Gmail cũ vẫn dùng được cho đến khi xác nhận thành công.',
                  ),
                  const SizedBox(height: 16),
                  _codeField(_oldCode, 'Mã gửi tới Gmail hiện tại'),
                  if (_needsNewCode) ...[
                    const SizedBox(height: 16),
                    _codeField(_newCode, 'Mã gửi tới Gmail mới'),
                  ] else ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Quyền sở hữu Gmail mới đã được xác minh qua Google.',
                    ),
                  ],
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
            onPressed: _busy || (!confirming && _resendSeconds > 0)
                ? null
                : (confirming ? _confirm : _request),
            child: Text(
              _busy
                  ? 'Đang xử lý…'
                  : (confirming ? 'Xác nhận đổi Gmail' : 'Gửi yêu cầu'),
            ),
          ),
        ],
      ),
    );
  }
}
