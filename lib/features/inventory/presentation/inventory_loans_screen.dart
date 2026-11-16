import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_store.dart';
import '../../settings/providers/shop_provider.dart';

typedef _Row = Map<String, dynamic>;
typedef _Choice = ({int id, String label});
typedef _Field = ({String key, String label, List<_Choice> options});

const _loans = '/inventory/loans';

final _loansProvider = FutureProvider.autoDispose.family<List<_Row>, int>((
  ref,
  shop,
) async {
  final data = await ref
      .read(apiClientProvider)
      .getOnlineInShop(
        _loans,
        '$shop',
        isCurrentScope: () =>
            ref.mounted && ref.read(shopProvider).currentShopId == shop,
      );
  return List<_Row>.from(data as List);
});

class InventoryLoansScreen extends ConsumerStatefulWidget {
  const InventoryLoansScreen({super.key});

  @override
  ConsumerState<InventoryLoansScreen> createState() =>
      _InventoryLoansScreenState();
}

class _InventoryLoansScreenState extends ConsumerState<InventoryLoansScreen> {
  bool _busy = false;
  final _operations = <String, String>{};

  Future<void> _change(
    int shop,
    String path,
    String title,
    int max, {
    bool create = false,
    bool warehouse = false,
    bool product = false,
    bool lending = false,
  }) async {
    if (_busy) return;
    final api = ref.read(apiClientProvider);
    bool current() => mounted && ref.read(shopProvider).currentShopId == shop;
    Future<dynamic> get(String path, {Map<String, dynamic>? params}) =>
        api.getOnlineInShop(
          path,
          '$shop',
          params: params,
          isCurrentScope: current,
        );

    setState(() => _busy = true);
    try {
      final fields = <_Field>[];
      if (create) {
        final partners = List<_Row>.from(
          await get('/inventory/partner-shops') as List,
        );
        fields.add((
          key: 'partnershipId',
          label: 'Đối tác',
          options: [
            for (final row in partners)
              if (row['status'] == 'ACTIVE')
                (id: row['id'] as int, label: row['partnerName'] as String),
          ],
        ));
      }
      if (warehouse) {
        final warehouses = List<_Row>.from(
          await get('/inventory/warehouses') as List,
        );
        fields.add((
          key: 'warehouseId',
          label: create ? 'Kho nhận' : 'Kho xuất',
          options: [
            for (final row in warehouses)
              (id: row['id'] as int, label: row['name'] as String),
          ],
        ));
      }
      if (product) {
        final products = <_Choice>[];
        for (var page = 1; current(); page++) {
          final result =
              await get('/products', params: {'page': page, 'limit': 100})
                  as Map;
          final rows = List<_Row>.from(result['items'] as List);
          products.addAll([
            for (final row in rows)
              (id: row['id'] as int, label: '${row['sku']} · ${row['name']}'),
          ]);
          if (page >= (result['totalPages'] as int? ?? 1)) break;
        }
        fields.add((
          key: lending ? 'lenderProductId' : 'productId',
          label: 'Sản phẩm',
          options: products,
        ));
      }
      if (!mounted || !current()) return;
      if (fields.any((field) => field.options.isEmpty)) {
        final field = fields.firstWhere((field) => field.options.isEmpty);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chưa có lựa chọn cho mục ${field.label}.')),
        );
        return;
      }
      final payload = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) =>
            _LoanActionDialog(title: title, fields: fields, max: max),
      );
      if (payload == null || !current()) return;
      final key =
          '$shop/$path/${payload.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      if (!create) {
        payload['operationId'] = _operations.putIfAbsent(key, () {
          final id = newOperationId();
          return '${id.substring(0, 8)}-${id.substring(8, 12)}-'
              '${id.substring(12, 16)}-${id.substring(16, 20)}-${id.substring(20)}';
        });
      }
      await api.postInShop(path, '$shop', payload, isCurrentScope: current);
      _operations.remove(key);
      if (current()) ref.invalidate(_loansProvider(shop));
    } catch (error) {
      if (mounted && current()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopProvider);
    final id = shop.currentShopId;
    return Scaffold(
      appBar: AppBar(title: const Text('Phiếu mượn hàng')),
      body: id == null || id < 1
          ? const Center(child: Text('Chọn một cửa hàng để xem phiếu.'))
          : ref
                .watch(_loansProvider(id))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(_loansProvider(id)),
                      child: const Text('Không tải được phiếu. Thử lại'),
                    ),
                  ),
                  data: (loans) => ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (shop.isOwner)
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _change(
                                    id,
                                    _loans,
                                    'Gửi yêu cầu mượn',
                                    2147483647,
                                    create: true,
                                    warehouse: true,
                                    product: true,
                                  ),
                            icon: const Icon(Icons.add),
                            label: const Text('Yêu cầu mượn'),
                          ),
                        ),
                      if (loans.isEmpty)
                        const ListTile(title: Text('Chưa có phiếu mượn hàng.')),
                      for (final loan in loans)
                        _loanCard(
                          id,
                          loan,
                          shop.hasPermission('inventory', 'edit'),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _loanCard(int shop, _Row loan, bool editable) {
    final shipments = List<_Row>.from(loan['shipments'] as List);
    final borrowing = loan['borrowing'] == true;
    final outstanding = loan['outstandingQuantity'] as int;
    final inTransitReturns = shipments
        .where((s) => s['direction'] == 'RETURN')
        .fold<int>(
          0,
          (sum, s) =>
              sum +
              (s['shippedQuantity'] as int) -
              (s['receivedQuantity'] as int),
        );
    final returnable = outstanding - inTransitReturns;
    final shipmentPath = '$_loans/${loan['id']}/shipments';
    final canAct = editable && !_busy && loan['canceledAt'] == null;
    return Card(
      child: ExpansionTile(
        title: Text('#${loan['id']} · ${loan['productName']}'),
        subtitle: Text(
          '${borrowing ? 'Mượn từ' : 'Cho mượn'} ${loan['partnerName']} · '
          'Còn phải hoàn $outstanding ${loan['unit']}',
        ),
        children: [
          ListTile(
            title: Text('Yêu cầu ${loan['requestedQuantity']} ${loan['unit']}'),
          ),
          for (final s in shipments) _shipment(shop, borrowing, s, canAct),
          if (canAct && !borrowing && shipments.isEmpty)
            TextButton(
              onPressed: () => _change(
                shop,
                shipmentPath,
                'Xác nhận xuất mượn',
                loan['requestedQuantity'] as int,
                warehouse: true,
                product: true,
                lending: true,
              ),
              child: const Text('Xuất hàng cho mượn'),
            ),
          if (canAct && borrowing && returnable > 0)
            TextButton(
              onPressed: () => _change(
                shop,
                shipmentPath,
                'Xác nhận xuất hoàn',
                returnable,
                warehouse: true,
              ),
              child: const Text('Gửi hoàn hàng'),
            ),
        ],
      ),
    );
  }

  Widget _shipment(int shop, bool borrowing, _Row shipment, bool canAct) {
    final isLoan = shipment['direction'] == 'LOAN';
    final inTransit =
        (shipment['shippedQuantity'] as int) -
        (shipment['receivedQuantity'] as int);
    return ListTile(
      title: Text(isLoan ? 'Lượt gửi mượn' : 'Lượt gửi hoàn'),
      subtitle: Text(
        'Đã gửi ${shipment['shippedQuantity']} · Đã nhận ${shipment['receivedQuantity']} · Đang giao $inTransit',
      ),
      trailing: canAct && inTransit > 0 && borrowing == isLoan
          ? TextButton(
              onPressed: () => _change(
                shop,
                '/inventory/loan-shipments/${shipment['id']}/receipts',
                'Xác nhận thực nhận',
                inTransit,
              ),
              child: const Text('Nhận hàng'),
            )
          : null,
    );
  }
}

class _LoanActionDialog extends StatefulWidget {
  const _LoanActionDialog({
    required this.title,
    required this.fields,
    required this.max,
  });
  final String title;
  final List<_Field> fields;
  final int max;

  @override
  State<_LoanActionDialog> createState() => _LoanActionDialogState();
}

class _LoanActionDialogState extends State<_LoanActionDialog> {
  final _form = GlobalKey<FormState>();
  final _values = <String, dynamic>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: Form(
        key: _form,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in widget.fields)
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  decoration: InputDecoration(labelText: field.label),
                  items: [
                    for (final item in field.options)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  validator: (value) => value == null
                      ? 'Chọn ${field.label.toLowerCase()}'
                      : null,
                  onChanged: (value) => _values[field.key] = value,
                ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Số lượng'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final quantity = int.tryParse(value?.trim() ?? '');
                  return quantity == null ||
                          quantity < 1 ||
                          quantity > widget.max
                      ? 'Số lượng không hợp lệ'
                      : null;
                },
                onSaved: (value) =>
                    _values['quantity'] = int.parse(value!.trim()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            _form.currentState!.save();
            Navigator.pop(context, _values);
          },
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
