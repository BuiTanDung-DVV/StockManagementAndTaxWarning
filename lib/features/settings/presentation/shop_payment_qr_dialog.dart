import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_service.dart';
import '../providers/system_provider.dart';

Future<void> showShopPaymentQrDialog(
  BuildContext context, {
  required bool canManage,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ShopPaymentQrDialog(canManage: canManage),
  );
}

class ShopPaymentQrDialog extends ConsumerStatefulWidget {
  final bool canManage;

  const ShopPaymentQrDialog({super.key, required this.canManage});

  @override
  ConsumerState<ShopPaymentQrDialog> createState() =>
      _ShopPaymentQrDialogState();
}

class _ShopPaymentQrDialogState extends ConsumerState<ShopPaymentQrDialog> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) {
        ToastService.showError('Ảnh QR phải không quá 4 MB');
        return;
      }

      final contentType =
          file.mimeType?.toLowerCase() ?? _contentTypeForName(file.name);
      if (!const {
        'image/jpeg',
        'image/png',
        'image/webp',
      }.contains(contentType)) {
        ToastService.showError('Chỉ hỗ trợ ảnh QR dạng JPG, PNG hoặc WEBP');
        return;
      }

      setState(() => _uploading = true);
      await ref
          .read(systemRepoProvider)
          .uploadShopPaymentQr(
            fileName: file.name,
            contentType: contentType,
            bytes: bytes,
          );
      ref.invalidate(shopPaymentQrProvider);
      if (mounted) ToastService.showSuccess('Đã cập nhật QR của cửa hàng');
    } on ApiException catch (error) {
      if (mounted) ToastService.showError(error.message);
    } catch (_) {
      if (mounted) ToastService.showError('Không thể tải ảnh QR lên');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _contentTypeForName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final qrAsync = ref.watch(shopPaymentQrProvider);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppAssetIcon(
                    assetPath: AppAssets.qrPayment,
                    size: 24,
                    semanticLabel: 'QR thanh toán',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'QR của cửa hàng',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: _uploading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              qrAsync.when(
                loading: () => const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => _QrErrorState(
                  onRetry: () => ref.invalidate(shopPaymentQrProvider),
                ),
                data: (imageUrl) => imageUrl == null
                    ? _EmptyQrState(
                        canManage: widget.canManage,
                        uploading: _uploading,
                        onUpload: _pickAndUpload,
                      )
                    : _QrPreview(
                        imageUrl: imageUrl,
                        canManage: widget.canManage,
                        uploading: _uploading,
                        onReplace: _pickAndUpload,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrPreview extends StatelessWidget {
  final String imageUrl;
  final bool canManage;
  final bool uploading;
  final VoidCallback onReplace;

  const _QrPreview({
    required this.imageUrl,
    required this.canManage,
    required this.uploading,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 280,
          height: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.divider),
          ),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Center(
              child: Text(
                'Không thể hiển thị ảnh QR',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted),
              ),
            ),
          ),
        ),
        if (canManage) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: uploading ? null : onReplace,
            child: Text(uploading ? 'Đang tải lên...' : 'Thay ảnh QR'),
          ),
        ],
      ],
    );
  }
}

class _EmptyQrState extends StatelessWidget {
  final bool canManage;
  final bool uploading;
  final VoidCallback onUpload;

  const _EmptyQrState({
    required this.canManage,
    required this.uploading,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          const AppAssetIcon(
            assetPath: AppAssets.qrPayment,
            size: 54,
            semanticLabel: 'Chưa có QR thanh toán',
          ),
          const SizedBox(height: 14),
          Text(
            'Cửa hàng chưa có ảnh QR',
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            canManage
                ? 'Chọn ảnh QR thanh toán từ thiết bị để nhân viên có thể mở nhanh khi cần.'
                : 'Vui lòng liên hệ chủ cửa hàng hoặc người có quyền cài đặt để bổ sung QR.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          if (canManage) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: uploading ? null : onUpload,
              child: Text(uploading ? 'Đang tải lên...' : 'Chọn ảnh QR'),
            ),
          ],
        ],
      ),
    );
  }
}

class _QrErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _QrErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không tải được QR của cửa hàng'),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
