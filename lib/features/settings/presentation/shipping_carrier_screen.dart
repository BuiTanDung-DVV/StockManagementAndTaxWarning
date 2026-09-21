import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/operations_provider.dart';

class ShippingCarrierScreen extends ConsumerStatefulWidget {
  const ShippingCarrierScreen({super.key});
  @override
  ConsumerState<ShippingCarrierScreen> createState() =>
      _ShippingCarrierScreenState();
}

class _ShippingCarrierScreenState extends ConsumerState<ShippingCarrierScreen> {
  Future<List<dynamic>>? _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
    _future = ref.read(settingsOperationsRepositoryProvider).carriers();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppThemeColors.of(context).bg,
    body: AppResponsiveContent(
      maxWidth: 1100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPageHeader(
            title: 'Đơn vị vận chuyển',
            subtitle:
                'Quản lý đối tác giao hàng, phí mặc định và đường dẫn tra cứu.',
            showBackButton: true,
            action: FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm đơn vị'),
            ),
            compactAction: IconButton.filled(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: OutlinedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Chưa tải được dữ liệu · Thử lại'),
                    ),
                  );
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: 360,
                        alignment: Alignment.center,
                        child: FilledButton.icon(
                          onPressed: () => _edit(),
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: const Text('Thêm đơn vị vận chuyển đầu tiên'),
                        ),
                      ),
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900 ? 2 : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * AppSpacing.md) /
                        columns;
                    return RefreshIndicator(
                      onRefresh: () async => _reload(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: items.map((raw) {
                            final item = Map<String, dynamic>.from(raw);
                            final active = item['isActive'] != false;
                            final feeValue = parseCurrency(
                              item['defaultFee']?.toString() ?? '0',
                            );
                            return SizedBox(
                              width: width,
                              child: AppCardContainer(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const CircleAvatar(
                                        child: Icon(
                                          Icons.local_shipping_outlined,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'].toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '${item['code']} · ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(feeValue)}',
                                            ),
                                            if (item['phone'] != null)
                                              Text(
                                                'Điện thoại: ${item['phone']}',
                                              ),
                                            Text(
                                              active
                                                  ? 'Đang sử dụng'
                                                  : 'Đã ngừng sử dụng',
                                              style: TextStyle(
                                                color: active
                                                    ? Colors.green
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (active)
                                        PopupMenuButton<String>(
                                          onSelected: (value) async {
                                            if (value == 'edit') {
                                              _edit(item);
                                            } else if (value == 'off') {
                                              final confirm =
                                                  await AppConfirmModal.show(
                                                    context,
                                                    title:
                                                        'Ngừng sử dụng đối tác vận chuyển?',
                                                    message:
                                                        'Bạn có chắc muốn ngừng hợp tác với "${item['name']}"? Đơn hàng cũ vẫn giữ nguyên thông tin đối tác này.',
                                                    confirmText:
                                                        'Ngừng sử dụng',
                                                    isDestructive: true,
                                                  );
                                              if (confirm == true) {
                                                _deactivate(item['id'] as int);
                                              }
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Chỉnh sửa'),
                                            ),
                                            PopupMenuItem(
                                              value: 'off',
                                              child: Text('Ngừng sử dụng'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _edit([Map<String, dynamic>? item]) async {
    var name = item?['name']?.toString() ?? '';
    var code = item?['code']?.toString() ?? '';
    var phone = item?['phone']?.toString() ?? '';
    var url = item?['trackingUrlTemplate']?.toString() ?? '';
    var fee = item?['defaultFee']?.toString() ?? '0';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final numericFee = parseCurrency(fee);
          final feeHelper = NumberFormat.currency(
            locale: 'vi_VN',
            symbol: '₫',
            decimalDigits: 0,
          ).format(numericFee);

          return AlertDialog(
            title: Text(item == null ? 'Thêm đơn vị vận chuyển' : 'Sửa đơn vị'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: name,
                      onChanged: (value) => name = value,
                      decoration: const InputDecoration(labelText: 'Tên *'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      initialValue: code,
                      onChanged: (value) => code = value,
                      decoration: const InputDecoration(labelText: 'Mã *'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      initialValue: phone,
                      onChanged: (value) => phone = value,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Điện thoại',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      initialValue: fee,
                      onChanged: (value) {
                        fee = value;
                        setModalState(() {});
                      },
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Phí mặc định',
                        helperText: 'Quy đổi: $feeHelper',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      initialValue: url,
                      onChanged: (value) => url = value,
                      decoration: const InputDecoration(
                        labelText: 'Mẫu URL tra cứu',
                        helperText:
                            'Có thể dùng {trackingCode} tại vị trí mã vận đơn.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () async {
                  if (name.trim().isEmpty) {
                    ToastService.showError(
                      'Vui lòng nhập tên đơn vị vận chuyển',
                    );
                    return;
                  }
                  if (code.trim().isEmpty) {
                    ToastService.showError(
                      'Vui lòng nhập mã đơn vị vận chuyển',
                    );
                    return;
                  }
                  final parsedFee = parseCurrency(fee);
                  if (parsedFee < 0) {
                    ToastService.showError(
                      'Phí vận chuyển mặc định không hợp lệ',
                    );
                    return;
                  }

                  try {
                    final data = {
                      'name': name.trim(),
                      'code': code.trim().toUpperCase(),
                      'phone': phone.trim(),
                      'trackingUrlTemplate': url.trim(),
                      'defaultFee': parsedFee,
                      'isActive': true,
                    };
                    final repo = ref.read(settingsOperationsRepositoryProvider);
                    item == null
                        ? await repo.createCarrier(data)
                        : await repo.updateCarrier(item['id'] as int, data);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } on ApiException catch (error) {
                    ToastService.showError(error.message);
                  } catch (_) {
                    ToastService.showError(
                      item == null
                          ? 'Không thể tạo đơn vị vận chuyển. Vui lòng thử lại sau.'
                          : 'Không thể cập nhật đơn vị vận chuyển. Vui lòng thử lại sau.',
                    );
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _deactivate(int id) async {
    try {
      await ref
          .read(settingsOperationsRepositoryProvider)
          .deactivateCarrier(id);
      _reload();
    } on ApiException catch (error) {
      ToastService.showError(error.message);
    } catch (_) {
      ToastService.showError(
        'Không thể vô hiệu hóa đơn vị vận chuyển. Vui lòng thử lại sau.',
      );
    }
  }
}
