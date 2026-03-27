import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/profile');
      final data = res['data'] ?? res;
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
      final res = await api.put('/profile', data: {
        'fullName': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      final updatedUser = res['data'] ?? res;
      // Update auth state with new user info
      final currentAuth = ref.read(authProvider);
      final merged = Map<String, dynamic>.from({...?currentAuth.user, ...updatedUser});
      ref.read(authProvider.notifier).updateUser(merged);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!'), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger));
      }
    }
    setState(() => _saving = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Avatar
                Center(child: Stack(children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      (_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : '?').toUpperCase(),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ])),
                const SizedBox(height: 8),
                Text(auth.user?['username'] ?? '', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                Text(
                  auth.accountType == 'SHOP' ? 'Tài khoản hộ kinh doanh' : 'Tài khoản cá nhân',
                  style: TextStyle(fontSize: 11, color: c.textMuted),
                ),
                const SizedBox(height: 24),

                // Form fields
                _buildField('Họ và tên', _nameCtrl, Icons.person, c),
                const SizedBox(height: 14),
                _buildField('Email', _emailCtrl, Icons.email, c, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _buildField('Số điện thoại', _phoneCtrl, Icons.phone, c, keyboardType: TextInputType.phone),
                const SizedBox(height: 28),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                    label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Change password
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showChangePasswordDialog(context),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Đổi mật khẩu'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, AppThemeColors c, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: c.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: currentCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại')),
          const SizedBox(height: 10),
          TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu mới')),
          const SizedBox(height: 10),
          TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Mật khẩu xác nhận không khớp'), backgroundColor: AppColors.danger));
                return;
              }
              try {
                final api = ref.read(apiClientProvider);
                await api.put('/profile/password', data: {'currentPassword': currentCtrl.text, 'newPassword': newCtrl.text});
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công!'), backgroundColor: AppColors.success));
                }
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger));
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
}
