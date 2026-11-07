import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/payment_amount.dart';
import '../../../core/utils/order_debt_balance.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../models/sales_payment.dart';
import '../models/sales_payment_recovery.dart';
import '../providers/sales_provider.dart';

class SalesPaymentDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  const SalesPaymentDialog({super.key, required this.order});
  @override
  ConsumerState<SalesPaymentDialog> createState() => _SalesPaymentDialogState();
}

class _SalesPaymentDialogState extends ConsumerState<SalesPaymentDialog> {
  final _amount = TextEditingController(), _notes = TextEditingController();
  late final int? _shop;
  late final String _actor;
  late DateTime _date;
  String _method = 'CASH';
  bool _busy = false, _pending = false, _scopeLost = false, _closing = false;
  bool _lookupSaved = false;
  String? _error, _amountError;
  Map<String, dynamic>? _request;
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
    _date = DateUtils.dateOnly(DateTime.now());
    _scopeLost =
        int.tryParse('${widget.order['shopId']}') != _shop ||
        !OrderDebtBalance.fromMap(widget.order).canCollect;
    _amount.text = NumberFormat('#,##0.##', 'vi_VN').format(_remaining);
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _remaining =>
      OrderDebtBalance.fromMap(widget.order).remaining ?? 0;

  bool _current() {
    if (!mounted || _scopeLost || _shop == null) return false;
    final auth = ref.read(authProvider), shop = ref.read(shopProvider);
    return auth.isLoggedIn &&
        !auth.isOfflineSession &&
        '${auth.user?['id']}' == _actor &&
        !shop.isAllShops &&
        shop.currentShopId == _shop &&
        shop.hasPermission('sales', 'edit');
  }

  Future<void> _send() async {
    if (_busy || !_current()) return;
    if (_request == null) {
      try {
        final amount = parsePaymentAmount(_amount.text);
        if (double.parse(amount) > _remaining) {
          throw const FormatException('Số tiền vượt phần còn phải thu');
        }
        final random = Random.secure();
        _request = {
          'operationId': List.generate(
            16,
            (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join(),
          'amount': amount,
          'method': _method,
          'paymentDate': DateFormat('yyyy-MM-dd').format(_date),
          'notes': _notes.text.trim(),
        };
      } catch (error) {
        setState(
          () => _amountError = error is FormatException
              ? error.message
              : 'Số tiền không hợp lệ',
        );
        return;
      }
    }
    setState(() {
      _busy = true;
      _pending = true;
      _error = null;
      _amountError = null;
    });
    try {
      // Save only a lookup identifier before sending, never an offline payment.
      try {
        if (!_lookupSaved) {
          await SalesPaymentRecovery(
            shopId: _shop!,
            actorId: _actor,
            orderId: widget.order['id'] as int,
            operationId: _request!['operationId'] as String,
            createdAt: DateTime.now(),
          ).save();
        }
        _lookupSaved = true;
      } catch (_) {
        if (mounted) {
          setState(() {
            _pending = false;
            _request = null;
            _error =
                'Chưa lưu được mã tra cứu trên thiết bị. Chưa gửi yêu cầu; hãy thử lại.';
          });
        }
        return;
      }
      if (!_current()) return;
      final result = await ref
          .read(salesRepoProvider)
          .recordPaymentInShop(
            widget.order['id'] as int,
            _shop!,
            _request!,
            _current,
          );
      if (_current()) await _complete(result);
    } catch (error) {
      if (error is ApiException && [400, 403, 404].contains(error.statusCode)) {
        try {
          await SalesPaymentRecovery.resolve(
            shopId: _shop!,
            actorId: _actor,
            operationId: _request!['operationId'] as String,
          );
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          if (error is ApiException &&
              [400, 403, 404].contains(error.statusCode)) {
            _pending = false;
            _request = null;
            _lookupSaved = false;
          }
          _error =
              error is ApiException &&
                  [400, 403, 404].contains(error.statusCode)
              ? error.message
              : 'Chưa xác nhận được kết quả. Kiểm tra hoặc thử lại cùng lượt ghi nhận để tránh ghi trùng.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete(SalesPaymentResult result) async {
    if (result.data['orderId'] != widget.order['id'] ||
        result.data['paymentDate'] != _request?['paymentDate'] ||
        result.data['method'] != _request?['method'] ||
        result.data['amount'] != double.parse(_request!['amount'] as String)) {
      throw const FormatException('Biên nhận không khớp khoản đang ghi nhận');
    }
    try {
      await SalesPaymentRecovery.resolve(
        shopId: _shop!,
        actorId: _actor,
        operationId: _request!['operationId'] as String,
      );
    } catch (_) {
      // Keeping a lookup identifier is safe; it cannot replay the payment.
    }
    if (!mounted || !_current()) return;
    _closing = true;
    Navigator.pop(context, true);
  }

  Future<void> _check() async {
    if (_busy || !_current() || _request == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(salesRepoProvider)
          .paymentStatusInShop(
            widget.order['id'] as int,
            _shop!,
            _request!['operationId'] as String,
            _current,
          );
      if (!_current()) return;
      if (result != null) {
        await _complete(result);
      } else {
        setState(
          () => _error =
              'Chưa tìm thấy lượt hoàn tất. Có thể thử lại cùng mã; hệ thống sẽ chống ghi trùng.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Chưa kiểm tra được kết quả. Giữ mã lượt ghi nhận và thử lại khi kết nối ổn định.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_pending) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Khoản ghi nhận chưa rõ kết quả'),
          content: SelectableText(
            'Đóng cửa sổ không hủy yêu cầu đã gửi. Mã ${_request?['operationId']} đã được lưu trên thiết bị này. Mở “Kiểm tra thu tiền” ở chi tiết đơn bán để đối chiếu trước khi ghi lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ở lại kiểm tra'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đóng cửa sổ'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _closing = true;
    Navigator.pop(context, _pending);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, next) {
      if (!_scopeLost &&
          (!next.isLoggedIn ||
              next.isOfflineSession ||
              '${next.user?['id']}' != _actor)) {
        setState(() => _scopeLost = true);
      }
    });
    ref.listen(shopProvider, (_, next) {
      if (!_scopeLost &&
          (next.currentShopId != _shop ||
              next.isAllShops ||
              !next.hasPermission('sales', 'edit'))) {
        setState(() => _scopeLost = true);
      }
    });
    final locked = _busy || _pending || !_current();
    return PopScope(
      canPop: _closing || (!_busy && !_pending),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy && !_closing) _close();
      },
      child: AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
          vertical: 24,
        ),
        title: const Text('Ghi nhận thu tiền'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đơn ${widget.order['orderCode'] ?? widget.order['id']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('Còn phải thu: ${_money.format(_remaining)}'),
                if ((num.tryParse(
                          '${widget.order['openingAdjustmentAmount']}',
                        ) ??
                        0) !=
                    0)
                  Text(
                    'Đã tính điều chỉnh đầu kỳ ${_money.format(widget.order['openingAdjustmentAmount'])}; khoản này không phải tiền đã thu.',
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amount,
                  enabled: !locked,
                  onChanged: (_) {
                    if (_amountError != null) {
                      setState(() => _amountError = null);
                    }
                  },
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Số tiền đã thu (VNĐ)',
                    errorText: _amountError,
                    errorMaxLines: 2,
                    helperText:
                        'Ví dụ: 150000 hoặc 150.000; phần lẻ: 150.000,50',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(
                    labelText: 'Phương thức nhận tiền',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Tiền mặt')),
                    DropdownMenuItem(
                      value: 'TRANSFER',
                      child: Text('Chuyển khoản'),
                    ),
                  ],
                  onChanged: locked
                      ? null
                      : (value) => setState(() => _method = value!),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size(double.infinity, 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: locked
                      ? null
                      : () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(1900),
                            lastDate: DateUtils.dateOnly(DateTime.now()),
                          );
                          if (selected != null && mounted && _current()) {
                            setState(() => _date = selected);
                          }
                        },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ngày đã thu',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(DateFormat('dd/MM/yyyy').format(_date)),
                          ],
                        ),
                      ),
                      const AppAssetIcon(
                        assetPath: AppAssets.calendar,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  enabled: !locked,
                  maxLength: 200,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (không bắt buộc)',
                  ),
                ),
                const Text(
                  'Chỉ ghi nhận khoản tiền bạn đã nhận; app không thực hiện chuyển tiền.',
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
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                if (_pending)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SelectableText(
                      'Mã lượt ghi nhận: ${_request?['operationId']}',
                    ),
                  ),
                if (_pending)
                  TextButton.icon(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: _request!['operationId'] as String),
                    ),
                    icon: const AppIcon(Icons.copy_outlined, size: 16),
                    label: const Text('Sao chép mã tra cứu'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _close,
            child: const Text('Đóng'),
          ),
          if (_pending)
            TextButton(
              onPressed: _busy || !_current() ? null : _check,
              child: const Text('Kiểm tra kết quả'),
            ),
          FilledButton(
            onPressed: _busy || !_current() ? null : _send,
            child: Text(
              _busy
                  ? 'Đang xử lý…'
                  : _pending
                  ? 'Thử lại cùng lượt'
                  : 'Ghi nhận đã thu',
            ),
          ),
        ],
      ),
    );
  }
}
