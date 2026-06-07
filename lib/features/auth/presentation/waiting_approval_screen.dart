import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../settings/providers/shop_provider.dart';
import '../providers/auth_provider.dart';

class WaitingApprovalScreen extends ConsumerWidget {
  const WaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: c.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.hourglass_empty_rounded,
                          size: 36,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Đang chờ duyệt',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: c.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Yêu cầu tham gia cửa hàng của bạn đã được gửi thành công. Vui lòng chờ Chủ cửa hàng hoặc Quản trị viên duyệt để truy cập vào hệ thống.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Tải lại trạng thái'),
                      onPressed: () async {
                        await ref.read(authProvider.notifier).init();
                        if (context.mounted) {
                          final shopState = ref.read(shopProvider);
                          if (shopState.isActive) {
                            context.go('/');
                          } else if (shopState.isRejected) {
                            ToastService.showSuccess(
                              'Yêu cầu của bạn đã bị từ chối.',
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Đăng xuất tài khoản'),
                      onPressed: () async {
                        final confirm = await AppConfirmModal.show(
                          context,
                          title: 'Đăng xuất',
                          message:
                              'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?',
                          confirmText: 'Đăng xuất',
                          cancelText: 'Hủy',
                          isDestructive: true,
                        );
                        if (confirm == true) {
                          ref.read(authProvider.notifier).logout();
                          if (context.mounted) context.go('/login');
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
