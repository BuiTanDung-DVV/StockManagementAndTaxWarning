import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
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
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/profile');
      final data = res;
      _nameCtrl.text = data['fullName'] ?? '';
      _emailCtrl.text = data['email'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
    } catch (_) {
      // Fallback to auth state
      final user = ref.read(authProvider).user;
      _nameCtrl.text = user?['fullName'] ?? '';
      _emailCtrl.text = user?['email'] ?? '';
      _phoneCtrl.text = user?['phone'] ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(
        '/profile',
        data: {
          'fullName': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
        },
      );
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
        ToastService.showError('Lỗi: $e');
      }
    }
    setState(() => _saving = false);
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
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar with Premium Glassmorphism Feel
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (_nameCtrl.text.isNotEmpty
                                    ? _nameCtrl.text[0]
                                    : '?')
                                .toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.card, width: 2.5),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    auth.user?['username'] ?? '',
                    style: GoogleFonts.outfit(
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
                    labelText: 'Email',
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    hasFocus: _emailHasFocus,
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    c: c,
                    theme: theme,
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
                          : const Icon(Icons.save_rounded, size: 20),
                      label: Text(
                        _saving ? 'Đang lưu...' : 'Lưu thay đổi',
                        style: GoogleFonts.outfit(
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
                      icon: const Icon(Icons.lock_reset_rounded, size: 20),
                      label: Text(
                        'Đổi mật khẩu bảo mật',
                        style: GoogleFonts.outfit(
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
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool hasFocus,
    required IconData icon,
    required AppThemeColors c,
    required ThemeData theme,
    TextInputType? keyboardType,
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
        style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon, color: c.textMuted, size: 20),
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
