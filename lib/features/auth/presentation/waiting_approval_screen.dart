import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/providers/shop_provider.dart';
import '../providers/auth_provider.dart';

class WaitingApprovalScreen extends ConsumerWidget {
  const WaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);

    return Scaffold(
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
                  const Icon(Icons.hourglass_empty, size: 80, color: AppColors.warning),
                  const SizedBox(height: 24),
                  const Text(
                    'Đang chờ duyệt',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yêu cầu tham gia cửa hàng của bạn đã được gửi. Vui lòng chờ Chủ cửa hàng / Quản trị viên duyệt yêu cầu.',
                    style: TextStyle(fontSize: 15, color: c.textSecondary, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tải lại trạng thái'),
                    onPressed: () async {
                      await ref.read(authProvider.notifier).init();
                      if (context.mounted) {
                        final shopState = ref.read(shopProvider);
                        if (shopState.isActive) {
                          context.go('/');
                        } else if (shopState.isRejected) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Yêu cầu của bạn đã bị từ chối.'), backgroundColor: AppColors.danger),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/login');
                    },
                    child: const Text('Đăng xuất', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
