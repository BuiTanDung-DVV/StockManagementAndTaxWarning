import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../../auth/providers/auth_provider.dart';
import 'avatar_picker_dialog.dart';
import 'profile_email_verification_dialog.dart';
import 'profile_email_change_dialog.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _nameHasFocus = false;
  bool _emailHasFocus = false;
  bool _phoneHasFocus = false;

  bool _loading = true;
  bool _saving = false;
  bool _loadError = false;
  bool? _emailVerified;
  bool? _hasPassword;
  bool? _googleLinked;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(
      () => setState(() => _nameHasFocus = _nameFocus.hasFocus),
    );
    _emailFocus.addListener(
      () => setState(() => _emailHasFocus = _emailFocus.hasFocus),
    );
    _phoneFocus.addListener(
      () => setState(() => _phoneHasFocus = _phoneFocus.hasFocus),
    );
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = Map<String, dynamic>.from(await api.get('/profile'));
      if (!mounted) return;
      _nameCtrl.text = data['fullName'] ?? '';
      _emailCtrl.text = data['email'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _username = data['username'] ?? '';
      _hasPassword = data['hasPassword'] is bool
          ? data['hasPassword'] as bool
          : null;
      _googleLinked = data['googleLinked'] is bool
          ? data['googleLinked'] as bool
          : null;
      _emailVerified = data['emailVerified'] is bool
          ? data['emailVerified'] as bool
          : null;
    } catch (_) {
      if (!mounted) return;
      _loadError = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(
        '/profile',
        data: {
          'fullName': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      final updatedUser = res;
      // Update auth state with new user info
      final currentAuth = ref.read(authProvider);
      final merged = Map<String, dynamic>.from({
        ...?currentAuth.user,
        ...updatedUser,
      });
      ref.read(authProvider.notifier).updateUser(merged);
      if (mounted) {
        ToastService.showSuccess('Cập nhật thành công!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError(
          'Không thể cập nhật thông tin cá nhân. Vui lòng thử lại sau.',
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _verifyEmail() async {
    final userId = ref.read(authProvider).user?['id'];
    final email = _emailCtrl.text.trim();
    final verified = await showDialog<bool>(
      context: context,
      builder: (_) => ProfileEmailVerificationDialog(email: email),
    );
    if (!mounted || verified != true) return;
    final user = ref.read(authProvider).user;
    if (user != null && user['id'] == userId) {
      setState(() => _emailVerified = true);
      ref.read(authProvider.notifier).updateUser({
        ...user,
        'email': email,
        'emailVerified': true,
      });
    }
  }

  Future<void> _changeEmail() async {
    final notifier = ref.read(authProvider.notifier);
    final userId = ref.read(authProvider).user?['id'];
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfileEmailChangeDialog(
        currentEmail: _emailCtrl.text.trim(),
        hasPassword: _hasPassword == true,
        googleLinked: _googleLinked == true,
      ),
    );
    if (!mounted ||
        result == null ||
        ref.read(authProvider).user?['id'] != userId) {
      return;
    }
    ToastService.showSuccess(
      'Đã đổi Gmail. Hãy đăng nhập lại bằng ${result['email']}.',
    );
    await notifier.finishEmailChange();
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Thông tin cá nhân',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(onPressed: () => Navigator.pop(context))
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Không thể tải thông tin cá nhân. Vui lòng thử lại.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loadProfile,
                      icon: const AppIcon(Icons.refresh_rounded, size: 20),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar with AppAvatar & Preset / Upload Picker
                  Center(
                    child: AppAvatar(
                      size: 96,
                      displayName: _nameCtrl.text,
                      showEditBadge: true,
                      borderWidth: 2,
                      borderColor: theme.colorScheme.primary.withValues(
                        alpha: 0.25,
                      ),
                      onTap: () => AvatarPickerDialog.show(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _username.contains('@') ? _emailCtrl.text : _username,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.accountType == 'SHOP'
                        ? 'Tài khoản chủ doanh nghiệp'
                        : 'Tài khoản nhân viên',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: c.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form fields
                  _buildGlowingField(
                    labelText: 'Họ và tên *',
                    controller: _nameCtrl,
                    focusNode: _nameFocus,
                    hasFocus: _nameHasFocus,
                    icon: Icons.person_outline_rounded,
                    c: c,
                    theme: theme,
                  ),
                  const SizedBox(height: 16),
                  _buildGlowingField(
                    labelText: 'Gmail',
                    helperText: _emailCtrl.text.trim().isEmpty
                        ? 'Chưa có Gmail'
                        : switch (_emailVerified) {
                            true => 'Đã xác minh',
                            false => 'Chưa xác minh',
                            null => 'Chưa có thông tin xác minh',
                          },
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    hasFocus: _emailHasFocus,
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true,
                    c: c,
                    theme: theme,
                  ),
                  if (_hasPassword != null &&
                      _googleLinked != null &&
                      _emailVerified == false &&
                      _emailCtrl.text.trim().isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _saving ? null : _verifyEmail,
                        child: const Text('Xác minh Gmail'),
                      ),
                    ),
                  if (_emailVerified == true &&
                      _emailCtrl.text.trim().isNotEmpty &&
                      _hasPassword != null &&
                      _googleLinked != null &&
                      (_hasPassword == true || _googleLinked == true))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _saving ? null : _changeEmail,
                        child: const Text('Đổi Gmail'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildGlowingField(
                    labelText: 'Số điện thoại',
                    controller: _phoneCtrl,
                    focusNode: _phoneFocus,
                    hasFocus: _phoneHasFocus,
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    c: c,
                    theme: theme,
                  ),
                  const SizedBox(height: 40),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const AppIcon(Icons.save_rounded, size: 20),
                      label: Text(
                        _saving ? 'Đang lưu...' : 'Lưu thay đổi',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Change password
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/change-password'),
                      icon: const AppIcon(Icons.lock_reset_rounded, size: 20),
                      label: Text(
                        'Đổi mật khẩu bảo mật',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.textPrimary,
                        side: BorderSide(color: c.divider),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGlowingField({
    required String labelText,
    String? helperText,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool hasFocus,
    required IconData icon,
    required AppThemeColors c,
    required ThemeData theme,
    TextInputType? keyboardType,
    bool readOnly = false,
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
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
        decoration: InputDecoration(
          labelText: labelText,
          helperText: helperText,
          prefixIcon: AppIcon(icon, color: c.textMuted, size: 20),
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
