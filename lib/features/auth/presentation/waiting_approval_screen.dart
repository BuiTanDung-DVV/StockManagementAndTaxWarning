import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../settings/providers/shop_provider.dart';
import '../providers/auth_provider.dart';

class WaitingApprovalScreen extends ConsumerWidget {
  const WaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      brandHeadline: 'Hồ sơ đang chờ phê duyệt truy cập.',
      brandDescription:
          'Yêu cầu tham gia cửa hàng đang được kiểm tra. Bạn sẽ có quyền truy cập ngay khi chủ cửa hàng xác nhận.',
      brandCapabilities: const [
        'Bảo vệ dữ liệu kinh doanh của cửa hàng',
        'Phân quyền tài khoản theo đúng vai trò',
        'Thông báo trạng thái tự động và an toàn',
      ],
      title: 'Đang chờ duyệt',
      subtitle:
          'Yêu cầu tham gia cửa hàng của bạn đã được gửi thành công. Vui lòng chờ Chủ cửa hàng duyệt để bắt đầu làm việc.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 32,
                color: AppColors.warning,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          FilledButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Tải lại trạng thái'),
            onPressed: () async {
              await ref.read(authProvider.notifier).init();
              if (context.mounted) {
                final shopState = ref.read(shopProvider);
                if (shopState.isActive) {
                  context.go('/');
                } else if (shopState.isRejected) {
                  ToastService.showSuccess('Yêu cầu của bạn đã bị từ chối.');
                } else {
                  ToastService.showInfo(
                    'Hồ sơ vẫn đang chờ chủ cửa hàng duyệt.',
                  );
                }
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          TextButton.icon(
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Đăng xuất tài khoản'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () async {
              final confirm = await AppConfirmModal.show(
                context,
                title: 'Đăng xuất',
                message: 'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?',
                confirmText: 'Đăng xuất',
                cancelText: 'Hủy',
                isDestructive: true,
              );
              if (confirm == true) {
                ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
