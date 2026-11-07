import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/finance_display.dart';
import '../../../core/utils/parse_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../models/manual_cash_repeat.dart';
import '../providers/finance_provider.dart';

class RepeatCashTransactionDialog extends ConsumerStatefulWidget {
  final ManualCashRepeat source;
  const RepeatCashTransactionDialog({super.key, required this.source});
  @override
  ConsumerState<RepeatCashTransactionDialog> createState() =>
      _RepeatCashTransactionDialogState();
}

class _RepeatCashTransactionDialogState
    extends ConsumerState<RepeatCashTransactionDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _counterparty;
  late final TextEditingController _notes;
  late final int? _actor;
  late final int? _shop;
  late DateTime _date;
  String? _method;
  String? _error;
  bool _saving = false;
  bool _needsCheck = false;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _amount = TextEditingController(
      text: source.amount == source.amount.roundToDouble()
          ? source.amount.toStringAsFixed(0)
          : source.amount.toString(),
    );
    _counterparty = TextEditingController(text: source.counterparty);
    _notes = TextEditingController(text: source.notes);
    _method = source.paymentMethod;
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _actor = int.tryParse('${ref.read(authProvider).user?['id']}');
    _shop = ref.read(shopProvider).currentShopId;
  }

  bool _sameScope() {
    if (!mounted || _actor == null || _shop == null) return false;
    final auth = ref.read(authProvider);
    final shop = ref.read(shopProvider);
    return auth.isLoggedIn &&
        !auth.isOfflineSession &&
        '${auth.user?['id']}' == '$_actor' &&
        shop.currentShopId == _shop &&
        !shop.isAllShops &&
        shop.hasPermission('finance', 'edit') &&
        (widget.source.shopId == null || widget.source.shopId == _shop);
  }

  Future<void> _save() async {
    if (_saving || _needsCheck || !_form.currentState!.validate()) return;
    if (!_sameScope()) {
      setState(
        () => _error =
            'Tài khoản, cửa hàng hoặc quyền đã thay đổi. Đóng biểu mẫu và mở lại giao dịch.',
      );
      return;
    }
    final today = DateTime.now();
    if (_date.isAfter(DateTime(today.year, today.month, today.day))) {
      setState(() => _error = 'Ngày giao dịch không được ở tương lai.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(financeRepoProvider)
          .createTransactionInShop(
            widget.source.payload(
              amount: parseCurrency(_amount.text),
              date: _date,
              method: _method!,
              counterparty: _counterparty.text,
              notes: _notes.text,
            ),
            _shop!,
            isCurrentScope: _sameScope,
          );
      if (!mounted) return;
      if (!_sameScope()) {
        setState(() {
          _needsCheck = true;
          _error =
              'Phạm vi đã thay đổi trong lúc lưu. Kiểm tra danh sách giao dịch của cửa hàng ban đầu trước khi ghi lại.';
        });
        return;
      }
      if ((int.tryParse('${result['id']}') ?? 0) <= 0) {
        throw ApiException(
          'Chưa xác nhận được kết quả. Kiểm tra danh sách giao dịch trước khi thử lại.',
        );
      }
      ref.invalidate(transactionsProvider);
      ref.invalidate(cashSummaryProvider);
      ref.invalidate(cashAccountsProvider);
      ref.invalidate(expensesByCategoryProvider);
      ref.invalidate(expensesByCategoryForPeriodProvider);
      ref.invalidate(profitLossProvider);
      ref.invalidate(dailyClosingProvider);
      ref.invalidate(cashflowProjectionProvider);
      ref.invalidate(budgetPlansProvider);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _needsCheck =
              error is! ApiException ||
              error.statusCode == null ||
              error.statusCode! >= 500;
          _error = _needsCheck
              ? 'Chưa xác nhận được kết quả lưu. Đóng biểu mẫu và kiểm tra danh sách giao dịch trước khi ghi lại.'
              : (error as ApiException).message;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _counterparty.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.source.type == 'INCOME' ? 'thu' : 'chi';
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text('Ghi lại khoản $label'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Kiểm tra ngày và số tiền cho lần ghi mới. Giao dịch cũ được giữ nguyên.',
                  ),
                  const SizedBox(height: 16),
                  Text('Nhóm: ${financeCategoryLabel(widget.source.category)}'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amount,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Số tiền *',
                      suffixText: '₫',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final amount = parseCurrency(value);
                      return amount.isFinite && amount > 0
                          ? null
                          : 'Nhập số tiền lớn hơn 0.';
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (date != null && mounted) {
                              setState(() => _date = date);
                            }
                          },
                    icon: const AppIcon(
                      Icons.calendar_today_outlined,
                      size: 18,
                    ),
                    label: Text(
                      'Ngày giao dịch: ${DateFormat('dd/MM/yyyy').format(_date)}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    decoration: const InputDecoration(
                      labelText: 'Phương thức *',
                    ),
                    items:
                        const [
                              'CASH',
                              'TRANSFER',
                              'QR',
                              'CARD',
                              'MOMO',
                              'ZALOPAY',
                            ]
                            .map(
                              (method) => DropdownMenuItem(
                                value: method,
                                child: Text(financePaymentMethodLabel(method)),
                              ),
                            )
                            .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _method = value),
                    validator: (value) => value == null
                        ? 'Chọn phương thức cho giao dịch mới.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _counterparty,
                    enabled: !_saving,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Đối tác'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notes,
                    enabled: !_saving,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Ghi chú'),
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
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: Text(_needsCheck ? 'Đóng' : 'Hủy'),
          ),
          FilledButton(
            onPressed: _saving || _needsCheck ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Lưu khoản $label'),
          ),
        ],
      ),
    );
  }
}
