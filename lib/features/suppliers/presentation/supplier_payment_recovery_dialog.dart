import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../models/supplier_payment.dart';
import '../models/supplier_payment_recovery.dart';
import '../providers/supplier_provider.dart';

class SupplierPaymentRecoveryDialog extends ConsumerStatefulWidget {
  final int supplierId;
  final String supplierName;
  const SupplierPaymentRecoveryDialog({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });
  @override
  ConsumerState<SupplierPaymentRecoveryDialog> createState() =>
      _SupplierPaymentRecoveryDialogState();
}

class _SupplierPaymentRecoveryDialogState
    extends ConsumerState<SupplierPaymentRecoveryDialog> {
  final _code = TextEditingController();
  late final int? _shop;
  late final String _actor;
  bool _busy = false, _scopeLost = false, _confirmed = false;
  String? _inputError, _error, _storageError;
  bool _unknown = false;
  List<SupplierPaymentRecovery> _pending = [];
  SupplierPaymentResult? _result;
  @override
  void initState() {
    super.initState();
    _shop = ref.read(shopProvider).currentShopId;
    _actor = '${ref.read(authProvider).user?['id']}';
    unawaited(_load());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool _current() {
    if (!mounted || _scopeLost || _shop == null) return false;
    final auth = ref.read(authProvider), shop = ref.read(shopProvider);
    return auth.isLoggedIn &&
        !auth.isOfflineSession &&
        '${auth.user?['id']}' == _actor &&
        !shop.isAllShops &&
        shop.currentShopId == _shop &&
        shop.hasPermission('finance', 'edit');
  }

  Future<void> _load() async {
    if (!_current()) return;
    try {
      final pending = await SupplierPaymentRecovery.pending(
        shopId: _shop!,
        actorId: _actor,
        supplierId: widget.supplierId,
      );
      if (_current()) setState(() => _pending = pending);
    } catch (_) {
      if (_current()) {
        setState(
          () => _storageError =
              'Chưa đọc được mã đã lưu trên thiết bị. Bạn vẫn có thể dán mã đã sao chép để kiểm tra.',
        );
      }
    }
  }

  Future<void> _check() async {
    if (_busy || !_current()) return;
    final code = _code.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{16,80}$').hasMatch(code)) {
      setState(() => _inputError = 'Dán mã lượt ghi nhận gồm 16–80 ký tự');
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
      _unknown = false;
      _error = null;
      _inputError = null;
    });
    try {
      final result = await ref
          .read(supplierRepoProvider)
          .paymentStatusInShop(_shop!, code, _current);
      if (!_current()) return;
      if (result == null) {
        setState(() => _unknown = true);
      } else if (result.data['supplierId'] != widget.supplierId ||
          result.data['operationId'] != code ||
          result.data['shopId'] != _shop) {
        setState(
          () => _error =
              'Mã tra cứu không thuộc nhà cung cấp và cửa hàng đang xem.',
        );
      } else {
        try {
          await SupplierPaymentRecovery.resolve(
            shopId: _shop,
            actorId: _actor,
            operationId: code,
          );
        } catch (_) {
          // A leftover lookup identifier cannot create another payment.
        }
        if (!_current()) return;
        setState(() {
          _result = result;
          _confirmed = true;
        });
        await _load();
      }
    } catch (error) {
      if (_current()) {
        setState(
          () => _error =
              error is ApiException &&
                  [400, 403, 404].contains(error.statusCode)
              ? error.message
              : 'Chưa kiểm tra được kết quả. Hãy kiểm tra kết nối và thử lại; không ghi lại bằng mã mới.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, next) {
      if (!_scopeLost &&
          (!next.isLoggedIn ||
              next.isOfflineSession ||
              '${next.user?['id']}' != _actor)) {
        setState(() {
          _scopeLost = true;
          _result = null;
          _pending = [];
        });
      }
    });
    ref.listen(shopProvider, (_, next) {
      if (!_scopeLost &&
          (next.currentShopId != _shop ||
              next.isAllShops ||
              !next.hasPermission('finance', 'edit'))) {
        setState(() {
          _scopeLost = true;
          _result = null;
          _pending = [];
        });
      }
    });
    final locked = _busy || !_current();
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final result = _result?.data;
    return AlertDialog(
      title: const Text('Kiểm tra trả nợ'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.supplierName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tra cứu lượt đã gửi, kể cả sau khi đóng cửa sổ hoặc tải lại trang. Thao tác này không ghi thêm tiền.',
              ),
              if (_storageError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_storageError!),
                ),
              if (_pending.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Lượt chưa rõ kết quả trên thiết bị này',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: ListView(
                    shrinkWrap: true,
                    children: _pending
                        .map(
                          (entry) => Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: locked
                                  ? null
                                  : () {
                                      _code.text = entry.operationId;
                                      _check();
                                    },
                              child: Text(
                                'Khoản #${entry.payableId} · ${DateFormat('dd/MM HH:mm').format(entry.createdAt.toLocal())} · Kiểm tra',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                enabled: !locked,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {
                  _inputError = null;
                  _error = null;
                  _result = null;
                  _unknown = false;
                }),
                onSubmitted: (_) => _check(),
                decoration: InputDecoration(
                  labelText: 'Mã lượt ghi nhận',
                  errorText: _inputError,
                  errorMaxLines: 2,
                ),
              ),
              if (_scopeLost)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Cửa hàng, tài khoản hoặc quyền đã thay đổi. Hãy đóng cửa sổ và kiểm tra lại.',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_unknown)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Chưa tìm thấy lượt hoàn tất. Yêu cầu có thể chưa xử lý xong; hãy kiểm tra lại hoặc đối chiếu sổ chi trước khi ghi lại.',
                  ),
                ),
              if (result != null) ...[
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đã ghi nhận',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          money.format(result['amount']),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ngày đã trả: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(result['paymentDate'] as String))}',
                        ),
                        Text(
                          'Khoản nợ #${result['payableId']} · Phiếu chi #${result['cashTransactionId']}',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Phần còn nợ ngay sau lượt này: ${money.format(result['remaining'])}',
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Đây là số dư tại thời điểm ghi nhận; công nợ hiện tại có thể đã thay đổi.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: result != null
              ? _check
              : () => Navigator.pop(context, _confirmed && _current()),
          child: Text(result != null ? 'Kiểm tra lại' : 'Đóng'),
        ),
        FilledButton(
          onPressed: locked
              ? null
              : result != null
              ? () => Navigator.pop(context, true)
              : _check,
          child: Text(
            _busy
                ? 'Đang kiểm tra…'
                : result != null
                ? 'Đóng'
                : 'Kiểm tra kết quả',
          ),
        ),
      ],
    );
  }
}
