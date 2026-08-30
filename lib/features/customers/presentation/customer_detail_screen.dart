import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/cloudinary_image.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/customer_provider.dart';
import '../../sales/providers/sales_provider.dart';
import 'customer_form_screen.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:go_router/go_router.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const CustomerDetailScreen({super.key, required this.id});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  int _ordersPage = 1;
  bool _uploadingEvidence = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final customerAsync = ref.watch(customerDetailProvider(widget.id));
    final compactLayout = MediaQuery.sizeOf(context).width < 720;
    Future<void> openEdit() async {
      final customer = customerAsync.value;
      if (customer == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerFormScreen(customer: customer),
        ),
      );
      ref.invalidate(customerDetailProvider(widget.id));
    }

    final receivablesAsync = ref.watch(customerReceivablesProvider(widget.id));
    final evidenceAsync = ref.watch(customerEvidenceProvider(widget.id));
    final ordersAsync = ref.watch(
      salesListProvider((
        page: _ordersPage,
        status: null,
        customerId: widget.id,
        search: null,
        from: null,
        to: null,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text('Khách hàng #${widget.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Xóa khách hàng',
            onPressed: () => _confirmDelete(context, ref),
          ),
          featureGuideButton(context, 'customer_detail'),
          if (!compactLayout && customerAsync.hasValue)
            AppPrimaryPageAction(
              label: 'Chỉnh sửa',
              assetPath: AppAssets.edit,
              onPressed: openEdit,
            ),
          if (compactLayout && customerAsync.hasValue)
            AppPrimaryHeaderAction(
              label: 'Chỉnh sửa',
              assetPath: AppAssets.edit,
              heroTag: 'customer-edit-compact',
              onPressed: openEdit,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: customerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (c) {
          final name = c['name'] ?? 'Khách hàng ${widget.id}';
          final phone = c['phone'] ?? '';
          final email = c['email'] ?? '';
          final address = c['address'] ?? '';
          final customerType = c['customerType'] ?? 'RETAIL';
          final balance = num.tryParse(c['balance']?.toString() ?? '') ?? 0;
          final creditLimit =
              num.tryParse(c['creditLimit']?.toString() ?? '') ?? 0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: TextStyle(
                      fontSize: 24,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (customerType.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 4),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      customerType,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                _Card([
                  if (phone.isNotEmpty) _Row('SĐT', phone),
                  if (email.isNotEmpty) _Row('Email', email),
                  if (address.isNotEmpty) _Row('Địa chỉ', address),
                  _Row('Mã KH', c['code'] ?? ''),
                  if (c['taxCode'] != null) _Row('MST', c['taxCode']),
                ]),
                const SizedBox(height: 12),
                _Card([
                  _Row('Công nợ', _currFmt.format(balance)),
                  _Row('Hạn mức tín dụng', _currFmt.format(creditLimit)),
                ]),
                const SizedBox(height: 12),
                if (phone.isEmpty && email.isEmpty && address.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Thông tin liên hệ chưa được cập nhật',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),

                const SizedBox(height: 16),
                _EvidenceSection(
                  evidenceAsync: evidenceAsync,
                  uploading: _uploadingEvidence,
                  onAdd: () => _pickAndUploadEvidence(receivablesAsync),
                  onDelete: _confirmDeleteEvidence,
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Lịch sử đơn hàng',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                ordersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Lỗi: $e'),
                  ),
                  data: (d) {
                    final items = (d['items'] as List?) ?? [];
                    final currentPage = paginationValue(
                      d,
                      'page',
                      fallback: _ordersPage,
                    );
                    final totalPages = paginationValue(
                      d,
                      'totalPages',
                      fallback: 1,
                    );
                    final totalItems = paginationValue(
                      d,
                      'total',
                      fallback: items.length,
                    );
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Chưa có đơn hàng',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length + 1,
                      itemBuilder: (_, i) {
                        if (i == items.length) {
                          return AppPaginationBar(
                            currentPage: currentPage,
                            totalPages: totalPages,
                            totalItems: totalItems,
                            itemLabel: 'đơn hàng',
                            onPageChanged: (page) =>
                                setState(() => _ordersPage = page),
                          );
                        }
                        final order = items[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(order['orderCode'] ?? ''),
                            subtitle: Text(
                              order['orderDate']?.toString().substring(0, 10) ??
                                  '',
                            ),
                            trailing: Text(
                              _currFmt.format(
                                num.tryParse(
                                      order['totalAmount']?.toString() ?? '0',
                                    ) ??
                                    0,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAndUploadEvidence(
    AsyncValue<List<dynamic>> receivablesAsync,
  ) async {
    try {
      final receivables = receivablesAsync.hasValue
          ? receivablesAsync.value!
          : await ref.read(customerReceivablesProvider(widget.id).future);
      final openReceivables = receivables.where((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final amount = num.tryParse(map['amount']?.toString() ?? '') ?? 0;
        final paid = num.tryParse(map['paidAmount']?.toString() ?? '') ?? 0;
        final status = map['status']?.toString().toUpperCase() ?? '';
        return amount - paid > 0 && status != 'PAID' && status != 'CANCELLED';
      }).toList();

      if (openReceivables.isEmpty) {
        ToastService.showError(
          'Khách hàng chưa có khoản công nợ đang mở để gắn chứng từ',
        );
        return;
      }

      final receivableId = await _selectReceivable(openReceivables);
      if (receivableId == null || !mounted) return;

      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2200,
        imageQuality: 88,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) {
        ToastService.showError('Ảnh chứng từ phải không quá 4 MB');
        return;
      }
      final contentType =
          file.mimeType?.toLowerCase() ?? _contentTypeForName(file.name);
      if (!const {
        'image/jpeg',
        'image/png',
        'image/webp',
      }.contains(contentType)) {
        ToastService.showError('Chỉ hỗ trợ ảnh JPG, PNG hoặc WEBP');
        return;
      }

      setState(() => _uploadingEvidence = true);
      final repository = ref.read(customerRepoProvider);
      final uploaded = await repository.uploadEvidenceImage(
        fileName: file.name,
        contentType: contentType,
        bytes: bytes,
      );
      final objectKey = uploaded['objectKey']?.toString() ?? '';
      try {
        await repository.addEvidence(receivableId, {
          'type': 'PHOTO',
          'fileUrl': uploaded['imageUrl'],
          'fileName': file.name,
          'fileSize': uploaded['size'] ?? bytes.length,
          'description': 'Chứng từ công nợ',
        });
      } catch (_) {
        if (objectKey.isNotEmpty) {
          try {
            await repository.deletePendingEvidenceImage(objectKey);
          } catch (_) {
            // Cleanup is best effort after the database write failed.
          }
        }
        rethrow;
      }
      ref.invalidate(customerEvidenceProvider(widget.id));
      if (mounted) ToastService.showSuccess('Đã lưu chứng từ công nợ');
    } on ApiException catch (error) {
      if (mounted) ToastService.showError(error.message);
    } catch (_) {
      if (mounted) ToastService.showError('Không thể tải chứng từ lên');
    } finally {
      if (mounted) setState(() => _uploadingEvidence = false);
    }
  }

  Future<int?> _selectReceivable(List<dynamic> receivables) {
    if (receivables.length == 1) {
      return Future.value(
        int.tryParse((receivables.first as Map)['id'].toString()),
      );
    }
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  'Chọn khoản công nợ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: receivables.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = Map<String, dynamic>.from(
                      receivables[index] as Map,
                    );
                    final amount =
                        num.tryParse(item['amount']?.toString() ?? '') ?? 0;
                    final paid =
                        num.tryParse(item['paidAmount']?.toString() ?? '') ?? 0;
                    final dueDate = item['dueDate']?.toString();
                    return ListTile(
                      title: Text(
                        'Công nợ #${item['id']} · còn ${_currFmt.format(amount - paid)}',
                      ),
                      subtitle: Text(
                        dueDate == null || dueDate.length < 10
                            ? 'Chưa có hạn thanh toán'
                            : 'Hạn thanh toán ${dueDate.substring(0, 10)}',
                      ),
                      onTap: () => Navigator.pop(
                        sheetContext,
                        int.tryParse(item['id'].toString()),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteEvidence(Map<String, dynamic> evidence) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa chứng từ?'),
        content: const Text(
          'Ảnh sẽ bị xóa khỏi hồ sơ công nợ và kho lưu trữ. Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(customerRepoProvider)
          .deleteEvidence(int.parse(evidence['id'].toString()));
      ref.invalidate(customerEvidenceProvider(widget.id));
      if (mounted) ToastService.showSuccess('Đã xóa chứng từ');
    } on ApiException catch (error) {
      if (mounted) ToastService.showError(error.message);
    } catch (_) {
      if (mounted) ToastService.showError('Không thể xóa chứng từ');
    }
  }

  String _contentTypeForName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa khách hàng'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa khách hàng này? Mọi dữ liệu liên quan sẽ không thể khôi phục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final cancel = BotToast.showCustomLoading(
                toastBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              try {
                await ref.read(customerRepoProvider).delete(widget.id);
                cancel();
                BotToast.showText(text: 'Xóa khách hàng thành công');
                ref.invalidate(customerListProvider);
                if (context.mounted) context.pop();
              } catch (e) {
                cancel();
                BotToast.showText(text: 'Lỗi: $e');
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  final AsyncValue<List<dynamic>> evidenceAsync;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _EvidenceSection({
    required this.evidenceAsync,
    required this.uploading,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chứng từ công nợ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ảnh biên nhận, giấy xác nhận hoặc chữ ký',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: uploading ? null : onAdd,
                icon: uploading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppAssetIcon(
                        assetPath: AppAssets.add,
                        size: 16,
                        color: Colors.white,
                      ),
                label: Text(uploading ? 'Đang tải' : 'Thêm ảnh'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          evidenceAsync.when(
            loading: () => const SizedBox(
              height: 110,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Text(
              'Không tải được danh sách chứng từ',
              style: TextStyle(color: Colors.redAccent),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      AppAssetIcon(
                        assetPath: AppAssets.emptyDocument,
                        size: 42,
                        semanticLabel: 'Chưa có chứng từ',
                      ),
                      SizedBox(height: 8),
                      Text('Chưa có ảnh chứng từ công nợ'),
                    ],
                  ),
                );
              }
              return SizedBox(
                height: 164,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    final item = Map<String, dynamic>.from(items[index] as Map);
                    return _EvidenceTile(item: item, onDelete: onDelete);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _EvidenceTile({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final imageUrl = item['fileUrl']?.toString() ?? '';
    final uploadedAt = item['uploadedAt']?.toString() ?? '';
    final dateLabel = uploadedAt.length >= 10
        ? uploadedAt.substring(0, 10)
        : 'Không rõ ngày';
    return SizedBox(
      width: 150,
      child: Material(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: imageUrl.isEmpty
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 760,
                        maxHeight: 760,
                      ),
                      child: InteractiveViewer(
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, _, _) => const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('Không thể hiển thị ảnh chứng từ'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 105,
                width: double.infinity,
                child: imageUrl.isEmpty
                    ? const AppAssetIcon(
                        assetPath: AppAssets.emptyDocument,
                        size: 40,
                      )
                    : CachedNetworkImage(
                        imageUrl: optimizedCloudinaryImageUrl(
                          imageUrl,
                          width: 320,
                          height: 220,
                        ),
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const AppAssetIcon(
                          assetPath: AppAssets.emptyDocument,
                          size: 40,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 2, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Xóa chứng từ',
                      onPressed: () => onDelete(item),
                      icon: const AppAssetIcon(
                        assetPath: AppAssets.delete,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card(this.children);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppThemeColors.of(context).card,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: children),
  );
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppThemeColors.of(context).textSecondary,
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}
