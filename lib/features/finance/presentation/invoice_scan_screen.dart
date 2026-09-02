import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/invoice_scan_provider.dart';

class InvoiceScanScreen extends ConsumerStatefulWidget {
  const InvoiceScanScreen({super.key});

  @override
  ConsumerState<InvoiceScanScreen> createState() => _InvoiceScanScreenState();
}

class _InvoiceScanScreenState extends ConsumerState<InvoiceScanScreen> {
  int page = 1;
  bool uploading = false;

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final scans = ref.watch(invoiceScanListProvider(page));

    return Scaffold(
      backgroundColor: c.bg,
      body: AppResponsiveContent(
        maxWidth: 1100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Quét hóa đơn',
              subtitle:
                  'Nhận dạng ảnh, kiểm tra thủ công rồi mới tạo hóa đơn đầu vào.',
              showBackButton: true,
              action: FilledButton.icon(
                onPressed: uploading ? null : _pick,
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(uploading ? 'Đang xử lý…' : 'Chọn ảnh hóa đơn'),
              ),
              compactAction: IconButton.filled(
                onPressed: uploading ? null : _pick,
                icon: const Icon(Icons.add_a_photo_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (uploading) const LinearProgressIndicator(),
            Expanded(
              child: scans.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: OutlinedButton(
                    onPressed: () =>
                        ref.invalidate(invoiceScanListProvider(page)),
                    child: const Text('Chưa tải được danh sách · Thử lại'),
                  ),
                ),
                data: (data) {
                  final items = data['items'] as List? ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: FilledButton.icon(
                        onPressed: _pick,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Quét hóa đơn đầu tiên'),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, index) {
                            final item = Map<String, dynamic>.from(
                              items[index],
                            );
                            return AppCardContainer(
                              child: ListTile(
                                onTap: () => context.push(
                                  '/invoice-scans/${item['id']}',
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item['imageUrl'].toString(),
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const SizedBox(
                                      width: 52,
                                      child: Icon(Icons.receipt_long_outlined),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item['scanCode']?.toString() ?? 'Phiếu quét',
                                ),
                                subtitle: Text(_status(item)),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Trang $page/${data['totalPages'] ?? 1}'),
                          IconButton(
                            onPressed: page > 1
                                ? () => setState(() => page--)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            onPressed: page < (data['totalPages'] ?? 1)
                                ? () => setState(() => page++)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _status(Map<String, dynamic> item) => switch (item['status']) {
    'CONFIRMED' => 'Đã tạo hóa đơn',
    'REVIEW_REQUIRED' => 'Đã nhận dạng · Cần kiểm tra',
    'MANUAL_REQUIRED' => item['errorMessage']?.toString() ?? 'Cần nhập tay',
    'PROCESSING' => 'Đang nhận dạng ảnh',
    _ => 'Chờ xử lý',
  };

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 4 * 1024 * 1024) {
      ToastService.showError('Ảnh phải nhỏ hơn 4 MB');
      return;
    }
    final ext = file.name.split('.').last.toLowerCase();
    final type = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
        ? 'image/webp'
        : 'image/jpeg';
    setState(() => uploading = true);
    try {
      final scan = await ref
          .read(invoiceScanRepositoryProvider)
          .upload(bytes, file.name, type);
      ref.invalidate(invoiceScanListProvider(page));
      if (mounted) context.push('/invoice-scans/${scan['id']}');
    } catch (error) {
      ToastService.showError(error.toString());
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }
}
