import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../models/sales_return_preview.dart';
import '../providers/sales_provider.dart';

class SalesReturnDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  const SalesReturnDialog({super.key, required this.order});
  @override
  ConsumerState<SalesReturnDialog> createState() => _SalesReturnDialogState();
}

class _SalesReturnDialogState extends ConsumerState<SalesReturnDialog> {
  final _reason = TextEditingController();
  final _bodyScroll = ScrollController();
  final _errorKey = GlobalKey();
  late final int? _shop;
  late final String _actor;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _refundShipping = false,
      _busy = false,
      _unknown = false,
      _scopeLost = false,
      _closing = false;
  String? _error;
  bool _serverBlocked = false;
  Map<String, dynamic>? _request;
  final _returnCode =
      'RT${List.generate(9, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  final _quantities = <int, TextEditingController>{};
  final _selected = <int>{};
  List<ReturnableSalesLine> _lines = [];
  String? _initialInvalid;
  Map<int, int> get _chosen => {
    for (final id in _selected) id: int.tryParse(_quantities[id]!.text) ?? -1,
  };
  bool get _feeRefunded => (widget.order['returns'] as List? ?? [])
      .whereType<Map>()
      .any((r) => r['status'] == 'COMPLETED' && r['refundShippingFee'] == true);
  final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _shop = ref.read(shopProvider).currentShopId;
    _actor = '${ref.read(authProvider).user?['id']}';
    _scopeLost = widget.order['shopId'] != _shop;
    try {
      _lines = returnableSalesLines(widget.order);
      for (final line in _lines.where((l) => l.remaining > 0)) {
        _selected.add(line.productId);
        _quantities[line.productId] = TextEditingController(
          text: '${line.remaining}',
        );
      }
    } on FormatException catch (error) {
      _initialInvalid = error.message;
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    _bodyScroll.dispose();
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _current() {
    if (!mounted) return false;
    final auth = ref.read(authProvider), shop = ref.read(shopProvider);
    return mounted &&
        !_scopeLost &&
        auth.isLoggedIn &&
        !auth.isOfflineSession &&
        '${auth.user?['id']}' == _actor &&
        shop.currentShopId == _shop &&
        !shop.isAllShops &&
        shop.hasPermission('sales', 'edit');
  }

  bool _validReceipt(dynamic raw) =>
      raw is Map &&
      raw['id'] is int &&
      raw['id'] > 0 &&
      raw['shopId'] == _shop &&
      raw['order'] is Map &&
      raw['order']['id'] == widget.order['id'] &&
      raw['order']['shopId'] == _shop &&
      raw['status'] == 'COMPLETED' &&
      raw['returnCode'] == _returnCode &&
      num.tryParse('${raw['refundAmount']}') == _request?['refundAmount'] &&
      raw['refundShippingFee'] == _request?['refundShippingFee'];

  void _revealError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _errorKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 150),
          alignment: 1,
        );
      }
    });
  }

  Future<void> _send() async {
    if (_busy || _unknown || _serverBlocked || !_current()) return;
    try {
      final preview = SalesReturnPreview.fromOrder(
        widget.order,
        _refundShipping,
        quantities: _chosen,
      );
      final items = _chosen.entries
          .where((entry) => entry.value > 0)
          .map((entry) => {'productId': entry.key, 'quantity': entry.value})
          .toList();
      if (items.isEmpty || items.any((item) => item['productId'] == null)) {
        throw const FormatException('Không có sản phẩm hợp lệ để trả');
      }
      _request = {
        'returnCode': _returnCode,
        'refundAmount': preview.refund,
        'refundShippingFee': _refundShipping,
        'returnDate': DateFormat('yyyy-MM-dd').format(_date),
        'reason': _reason.text.trim(),
        'items': items,
      };
      setState(() {
        _busy = true;
        _error = null;
      });
      final raw = await ref
          .read(salesRepoProvider)
          .createReturnInShop(
            widget.order['id'] as int,
            _shop!,
            _request!,
            _current,
          );
      if (!mounted || !_current()) return;
      if (!_validReceipt(raw)) {
        throw const FormatException('Biên nhận trả hàng chưa khớp');
      }
      _closing = true;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted || !_current()) return;
      final definitive =
          error is ApiException && [400, 403, 404].contains(error.statusCode) ||
          error is FormatException && !_busy;
      setState(() {
        _unknown = !definitive;
        _serverBlocked = error is ApiException && error.statusCode == 403;
        _error = definitive
            ? (error is ApiException
                  ? error.message
                  : (error as FormatException).message)
            : error is ApiException && error.statusCode == 409
            ? '${error.message}\nKiểm tra phiếu trả trước khi ghi lại.'
            : 'Chưa xác nhận được kết quả. Kiểm tra phiếu trả hàng trước khi ghi lại để tránh hoàn tiền hai lần.';
      });
      _revealError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    if (_busy || !_current()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await ref
          .read(salesRepoProvider)
          .findByIdInShop(widget.order['id'] as int, _shop!, _current);
      if (!mounted || !_current()) return;
      final returns = (order['returns'] as List? ?? [])
          .where(
            (dynamic row) =>
                row is Map &&
                row['shopId'] == _shop &&
                row['id'] is int &&
                row['status'] == 'COMPLETED' &&
                row['returnCode'] == _request?['returnCode'] &&
                num.tryParse('${row['refundAmount']}') ==
                    _request?['refundAmount'],
          )
          .toList();
      if (returns.isNotEmpty) {
        _closing = true;
        Navigator.pop(context, true);
      } else {
        setState(
          () => _error =
              'Chưa tìm thấy phiếu hoàn tất. Đóng cửa sổ và tải lại đơn để đối chiếu trước khi ghi lại.',
        );
      }
    } catch (_) {
      if (_current()) {
        setState(
          () => _error =
              'Chưa kiểm tra được phiếu trả hàng. Hãy thử kiểm tra lại khi kết nối ổn định.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shopProvider, (_, next) {
      if (!_scopeLost &&
          (next.currentShopId != _shop ||
              next.isAllShops ||
              !next.hasPermission('sales', 'edit'))) {
        setState(() => _scopeLost = true);
      }
    });
    ref.listen(authProvider, (_, next) {
      if (!_scopeLost &&
          (!next.isLoggedIn ||
              next.isOfflineSession ||
              '${next.user?['id']}' != _actor)) {
        setState(() => _scopeLost = true);
      }
    });
    SalesReturnPreview? preview;
    String? invalid;
    try {
      preview = SalesReturnPreview.fromOrder(
        widget.order,
        _refundShipping,
        quantities: _chosen,
      );
    } on FormatException catch (error) {
      invalid = error.message;
    }
    final locked = _busy || _unknown || !_current();
    Widget row(String label, double amount, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _money.format(amount),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    invalid ??= _initialInvalid;
    return PopScope(
      canPop: _closing || !_busy,
      child: AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
          vertical: 24,
        ),
        title: const Text('Ghi nhận trả hàng'),
        content: SizedBox(
          width: 520,
          child: Scrollbar(
            controller: _bodyScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _bodyScroll,
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Đơn ${widget.order['orderCode'] ?? widget.order['id']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      shrinkWrap: true,
                      children: _lines.map((line) {
                        final item = line.item;
                        final product = item['product'] as Map? ?? {};
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _selected.contains(line.productId),
                                semanticLabel:
                                    'Trả ${product['name'] ?? line.productId}',
                                onChanged: locked || line.remaining == 0
                                    ? null
                                    : (value) => setState(() {
                                        value == true
                                            ? _selected.add(line.productId)
                                            : _selected.remove(line.productId);
                                        _error = null;
                                        _serverBlocked = false;
                                      }),
                              ),
                              ProductThumbnail(
                                imageUrl: product['imageUrl']?.toString(),
                                name: product['name']?.toString(),
                                size: 32,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${product['name'] ?? item['productName'] ?? 'Sản phẩm'}',
                                    ),
                                    Text(
                                      'Đã bán ${line.sold} · Đã trả ${line.returned} · Còn ${line.remaining} ${product['unit'] ?? ''}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    if (line.remaining > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: TextField(
                                          key: ValueKey(
                                            'return-quantity-${line.productId}',
                                          ),
                                          controller:
                                              _quantities[line.productId],
                                          enabled:
                                              !locked &&
                                              _selected.contains(
                                                line.productId,
                                              ),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Số lượng trả',
                                          ),
                                          onChanged: (_) => setState(() {
                                            _error = null;
                                            _serverBlocked = false;
                                          }),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (preview != null) ...[
                    row('Đã thu trên đơn', preview.paid),
                    row('Tiền hoàn cho khách', preview.refund, strong: true),
                    if (preview.retainedCash > 0)
                      row('Tiền đã thu còn giữ lại', preview.retainedCash),
                    if (preview.shipping > 0)
                      row('Phí giao hàng giữ lại', preview.shipping),
                    if (preview.adjustmentForShipping > 0)
                      row(
                        'Giảm nợ áp dụng cho phí giao',
                        preview.adjustmentForShipping,
                      ),
                    row(
                      'Còn phải thu sau trả',
                      preview.remaining,
                      strong: true,
                    ),
                  ],
                  if (!_feeRefunded &&
                      widget.order['shippingFeePayer'] == 'CUSTOMER' &&
                      (num.tryParse('${widget.order['shippingFee']}') ?? 0) > 0)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _refundShipping,
                      onChanged: locked
                          ? null
                          : (value) => setState(() => _refundShipping = value),
                      title: const Text('Hoàn cả phí giao hàng'),
                      subtitle: const Text(
                        'Hoàn phần phí đã thu và xóa phần phí còn nợ.',
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: locked
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(1900),
                              lastDate: DateUtils.dateOnly(DateTime.now()),
                            );
                            if (date != null && _current()) {
                              setState(() {
                                _date = date;
                                _serverBlocked = false;
                                _error = null;
                              });
                            }
                          },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ngày trả hàng: ${DateFormat('dd/MM/yyyy').format(_date)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reason,
                    enabled: !locked,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Lý do trả hàng (không bắt buộc)',
                    ),
                  ),
                  const Text(
                    'Ghi nhận việc hoàn tiền; ứng dụng không tự chuyển tiền. Phiếu chi được ghi theo phương thức đã thu trên đơn.',
                  ),
                  if (_scopeLost)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Cửa hàng, tài khoản hoặc quyền đã thay đổi. Hãy đóng cửa sổ và kiểm tra lại.',
                      ),
                    ),
                  if (invalid != null || _error != null)
                    Padding(
                      key: _errorKey,
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        invalid ?? _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    _closing = true;
                    Navigator.pop(context, _unknown);
                  },
            child: const Text('Đóng'),
          ),
          if (_unknown)
            FilledButton(
              onPressed: _busy || !_current() ? null : _check,
              child: Text(_busy ? 'Đang kiểm tra…' : 'Kiểm tra phiếu trả'),
            )
          else
            FilledButton(
              onPressed:
                  _busy || _serverBlocked || !_current() || invalid != null
                  ? null
                  : _send,
              child: Text(_busy ? 'Đang ghi nhận…' : 'Ghi nhận trả hàng'),
            ),
        ],
      ),
    );
  }
}
