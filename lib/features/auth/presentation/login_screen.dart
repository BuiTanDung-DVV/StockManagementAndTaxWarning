import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final success = await ref.read(authProvider.notifier).login(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (success && mounted) {
      // App shell uses "/" as the dashboard route.
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final state = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Aesthetic Login Header
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CachedNetworkImage(
                        imageUrl: 'https://images.unsplash.com/photo-1542744094-24638ea0bc40?q=80&w=1000&auto=format&fit=crop',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: 0.5),
                        colorBlendMode: BlendMode.darken,
                        placeholder: (context, url) => Container(color: AppColors.primary.withValues(alpha: 0.1)),
                        errorWidget: (context, url, _) => Container(color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.storefront, size: 36, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Quản lý Bán hàng', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('& Kho hàng', style: TextStyle(fontSize: 16, color: c.textSecondary)),
              SizedBox(height: 40),
              TextField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  hintText: 'Tên đăng nhập',
                  prefixIcon: Icon(Icons.person_outline, color: c.textMuted),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Mật khẩu',
                  prefixIcon: Icon(Icons.lock_outline, color: c.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: c.textMuted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _login,
                  child: state.isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Đăng nhập'),
                ),
              ),
              SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: Text('Quên mật khẩu?', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                ),
                Text('•', style: TextStyle(color: c.textMuted)),
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: Text('Đăng ký tài khoản', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
            ),
          ),
        ),
      ),
    );
  }
}
