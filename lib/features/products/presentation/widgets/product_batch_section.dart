import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/data_freshness_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../settings/providers/shop_provider.dart';

final productBatchesProvider = FutureProvider.autoDispose
    .family<List<dynamic>, int>((ref, id) async {
      ref.watch(shopProvider);
      watchDataFreshness(ref, DataArea.products);
      final result = await ref
          .watch(apiClientProvider)
          .get('/products/$id/batches');
      if (result is! List) {
        throw const FormatException('Dữ liệu lô không hợp lệ.');
      }
      return result;
    });

class ProductBatchSection extends ConsumerWidget {
  final int productId;
  const ProductBatchSection({super.key, required this.productId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lô hàng & hạn sử dụng',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Khai hạn dùng theo bao bì và hồ sơ nhập. Chỉnh ngày không làm thay đổi số lượng tồn kho.',
          ),
          const SizedBox(height: 12),
          ref
              .watch(productBatchesProvider(productId))
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => TextButton.icon(
                  onPressed: () =>
                      ref.invalidate(productBatchesProvider(productId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Chưa tải được lô. Thử lại'),
                ),
                data: (rows) => rows.isEmpty
                    ? const Text(
                        'Chưa có thông tin lô và hạn dùng để theo dõi.',
                      )
                    : Column(
                        children: rows
                            .whereType<Map>()
                            .map(
                              (batch) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${batch['batchNumber']}'),
                                subtitle: Text(
                                  'Còn ${batch['quantity']} · Hạn dùng: ${_displayDate(batch['expiryDate'])}${batch['quantitySource'] == 'LEGACY_BATCH' ? '\nSố lượng khai trên hồ sơ lô; chưa liên kết lô kho.' : ''}',
                                ),
                                trailing:
                                    ref
                                        .watch(shopProvider)
                                        .hasPermission('products', 'edit')
                                    ? IconButton(
                                        tooltip: 'Cập nhật hạn dùng',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () async {
                                          final saved = await showDialog<bool>(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) => _BatchDatesDialog(
                                              productId: productId,
                                              batch: Map<String, dynamic>.from(
                                                batch,
                                              ),
                                            ),
                                          );
                                          if (saved == true) {
                                            ref.invalidate(
                                              productBatchesProvider(productId),
                                            );
                                          }
                                        },
                                      )
                                    : null,
                              ),
                            )
                            .toList(),
                      ),
              ),
        ],
      ),
    ),
  );
}

String _displayDate(dynamic raw) {
  final date = DateTime.tryParse('$raw');
  return date == null ? 'Chưa khai' : DateFormat('dd/MM/yyyy').format(date);
}

class _BatchDatesDialog extends ConsumerStatefulWidget {
  final int productId;
  final Map<String, dynamic> batch;
  const _BatchDatesDialog({required this.productId, required this.batch});
  @override
  ConsumerState<_BatchDatesDialog> createState() => _BatchDatesDialogState();
}

class _BatchDatesDialogState extends ConsumerState<_BatchDatesDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _manufactured, _expires, _notes;
  late final int? _shop;
  late final String _actor;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    String text(dynamic date) =>
        DateTime.tryParse('$date') == null ? '' : _displayDate(date);
    _manufactured = TextEditingController(
      text: text(widget.batch['manufacturingDate']),
    );
    _expires = TextEditingController(text: text(widget.batch['expiryDate']));
    _notes = TextEditingController(text: '${widget.batch['notes'] ?? ''}');
    _shop = ref.read(shopProvider).currentShopId;
    _actor = '${ref.read(authProvider).user?['id']}';
  }

  @override
  void dispose() {
    _manufactured.dispose();
    _expires.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _date(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      DateFormat('dd/MM/yyyy').parseStrict(value.trim());
      return null;
    } catch (_) {
      return 'Nhập ngày hợp lệ theo dd/MM/yyyy';
    }
  }

  bool _current() =>
      mounted &&
      _shop != null &&
      ref.read(shopProvider).currentShopId == _shop &&
      ref.read(shopProvider).hasPermission('products', 'edit') &&
      ref.read(authProvider).isLoggedIn &&
      !ref.read(authProvider).isOfflineSession &&
      '${ref.read(authProvider).user?['id']}' == _actor;
  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (!_current()) {
      setState(
        () => _error = 'Cửa hàng hoặc quyền đã thay đổi. Đóng và mở lại.',
      );
      return;
    }
    DateTime? date(TextEditingController c) => c.text.trim().isEmpty
        ? null
        : DateFormat('dd/MM/yyyy').parseStrict(c.text.trim());
    final made = date(_manufactured), expiry = date(_expires);
    if (made != null && expiry != null && expiry.isBefore(made)) {
      setState(() => _error = 'Hạn sử dụng không được trước ngày sản xuất.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? formatted(DateTime? d) =>
          d == null ? null : DateFormat('yyyy-MM-dd').format(d);
      await ref
          .read(apiClientProvider)
          .putInShop(
            '/products/${widget.productId}/batches/${widget.batch['id']}',
            '$_shop',
            data: {
              'manufacturingDate': formatted(made),
              'expiryDate': formatted(expiry),
              'notes': _notes.text.trim(),
            },
            isCurrentScope: _current,
          );
      if (mounted && _current()) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Chưa lưu được thông tin lô. Kiểm tra kết nối rồi thử lại; các ô đã nhập được giữ nguyên.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Hạn dùng · ${widget.batch['batchNumber']}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Giữ nguyên lượng lô, giá vốn và tiền. Ngày để trống có nghĩa là chưa khai.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _manufactured,
                  enabled: !_busy,
                  validator: _date,
                  decoration: const InputDecoration(
                    labelText: 'Ngày sản xuất',
                    hintText: 'dd/MM/yyyy',
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _expires,
                  enabled: !_busy,
                  validator: _date,
                  decoration: const InputDecoration(
                    labelText: 'Hạn sử dụng',
                    hintText: 'dd/MM/yyyy',
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _notes,
                  enabled: !_busy,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Ghi chú lô'),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Đang lưu…' : 'Lưu hạn dùng'),
        ),
      ],
    ),
  );
}
