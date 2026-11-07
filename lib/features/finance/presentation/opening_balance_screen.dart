import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/business_date_field.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../dashboard/providers/dashboard_action_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../models/opening_balance.dart';
import '../providers/finance_provider.dart';
import '../providers/opening_balance_provider.dart';

class OpeningBalanceScreen extends ConsumerStatefulWidget {
  const OpeningBalanceScreen({super.key});
  @override
  ConsumerState<OpeningBalanceScreen> createState() =>
      _OpeningBalanceScreenState();
}

class _OpeningBalanceScreenState extends ConsumerState<OpeningBalanceScreen> {
  final _keys = <String, String>{
    'cash': 'Tiền mặt',
    'bank': 'Tiền gửi và chuyển khoản',
  };
  final _actual = <String, TextEditingController>{};
  final _cost = <String, TextEditingController>{};
  final _allocations = <String, Map<int, TextEditingController>>{};
  final _dueDates = <String, String>{};
  final _sourceLinks = <String, Map<String, dynamic>>{};
  late final int? _shop;
  late final String _actor;
  late DateTime _date;
  OpeningSnapshot? _snapshot;
  OpeningPreview? _preview;
  OpeningReceipt? _receipt;
  Map<String, dynamic>? _request, _pending;
  String? _error;
  bool _busy = false, _uncertain = false, _statusMissing = false;
  int _readEpoch = 0;

  @override
  void initState() {
    super.initState();
    _shop = ref.read(shopProvider).currentShopId;
    _actor = '${ref.read(authProvider).user?['id']}';
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    _date = DateTime(now.year, now.month, now.day);
  }

  bool _current() {
    if (!mounted || _shop == null) return false;
    final shop = ref.read(shopProvider), auth = ref.read(authProvider);
    return shop.isOwner &&
        shop.currentShopId == _shop &&
        auth.isLoggedIn &&
        !auth.isOfflineSession &&
        '${auth.user?['id']}' == _actor;
  }

  String get _day => DateFormat('yyyy-MM-dd').format(_date);
  OpeningBalanceRepository get _repo => ref.read(openingBalanceRepoProvider);
  void _clearFields() {
    for (final controller in [
      ..._actual.values,
      ..._cost.values,
      ..._allocations.values.expand((map) => map.values),
    ]) {
      controller.dispose();
    }
    _actual.clear();
    _cost.clear();
    _allocations.clear();
    _dueDates.clear();
  }

  @override
  void dispose() {
    _clearFields();
    super.dispose();
  }

  void _reset() {
    _sourceLinks.clear();
    final receipt = _receipt;
    if (receipt != null) {
      _date = DateTime.parse(receipt.plan['asOf']);
      final labels = {
        for (final row in (receipt.plan['rows'] as List))
          row['key'] as String:
              _snapshot?.label(row['key']) ??
              _keys[row['key']] ??
              row['key'] as String,
      };
      _keys
        ..clear()
        ..addAll(labels);
    }
    _readEpoch++;
    _clearFields();
    setState(() {
      _snapshot = null;
      _preview = null;
      _receipt = null;
      _request = null;
      _pending = null;
      _error = null;
      _statusMissing = false;
    });
  }

  void _changed() => setState(() {
    _preview = null;
    _request = null;
    _error = null;
  });

  Future<void> _read() async {
    if (_busy || !_current() || _keys.isEmpty) return;
    final epoch = ++_readEpoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await _repo.snapshot(
        _shop!,
        _day,
        _keys.keys.toList(),
        _current,
        sourceLinks: _sourceLinks.values.toList(),
      );
      if (!_current() || epoch != _readEpoch) return;
      _clearFields();
      for (final row in snapshot.rows) {
        final key = row['key'] as String;
        _actual[key] = TextEditingController(
          text:
              '${row['kind'] == 'STOCK' ? row['quantity'] : NumberFormat('#,##0.##', 'vi_VN').format(num.parse(row['amount']))}',
        );
        if (row['kind'] == 'STOCK') _cost[key] = TextEditingController();
        _allocations[key] = {
          for (final debt in (row['debts'] as List? ?? []))
            debt['id'] as int: TextEditingController(text: '0'),
        };
      }
      setState(() {
        _snapshot = snapshot;
        _preview = null;
        _receipt = null;
      });
    } catch (error) {
      if (_current()) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPreview() async {
    if (_busy || !_current() || _snapshot == null || _uncertain) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = <Map<String, dynamic>>[];
      for (final row in _snapshot!.rows) {
        final key = row['key'] as String, stock = row['kind'] == 'STOCK';
        final actual = stock
            ? openingBalanceQuantity(_actual[key]!.text)
            : openingBalanceAmount(_actual[key]!.text);
        final increase =
            num.parse('$actual') >
            num.parse('${stock ? row['quantity'] : row['amount']}');
        final decrease =
            num.parse('$actual') <
            num.parse('${stock ? row['quantity'] : row['amount']}');
        final debt = ['RECEIVABLE', 'PAYABLE'].contains(row['kind']);
        rows.add({
          'key': key,
          'actual': actual,
          if (stock && increase)
            'unitCost': openingBalanceAmount(_cost[key]!.text),
          if (debt && increase && _dueDates[key] != null)
            'dueDate': _dueDates[key],
          if (debt && decrease)
            'allocations': [
              for (final item in _allocations[key]!.entries)
                if (num.parse(openingBalanceAmount(item.value.text)) > 0)
                  {
                    'debtId': item.key,
                    'amount': openingBalanceAmount(item.value.text),
                  },
            ],
        });
      }
      final request = {
        'asOf': _day,
        'expectedRevision': _snapshot!.revision,
        'rows': rows,
        if (_sourceLinks.isNotEmpty)
          'sourceLinks': _sourceLinks.values.toList(),
      };
      final preview = await _repo.preview(_shop!, request, _current);
      if (!_current()) return;
      setState(() {
        _preview = preview;
        _request = request;
      });
    } catch (error) {
      if (_current()) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _accept(OpeningReceipt receipt) {
    if (!_current()) return;
    ref.invalidate(financeRepoProvider);
    ref.invalidate(inventoryRepoProvider);
    ref.invalidate(productRepoProvider);
    ref.invalidate(customerRepoProvider);
    ref.invalidate(supplierRepoProvider);
    ref.invalidate(dashboardActionProvider);
    setState(() {
      _receipt = receipt;
      _uncertain = false;
      _pending = null;
      _error = null;
    });
  }

  Future<void> _commit() async {
    if (_busy ||
        !_current() ||
        _preview?.canCommit != true ||
        _request == null) {
      return;
    }
    if (_pending == null) {
      final random = Random.secure();
      final operation = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _pending = jsonDecode(
        jsonEncode({
          ..._request!,
          'operationId': operation,
          'expectedPlanHash': _preview!.planHash,
        }),
      );
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _accept(await _repo.commit(_shop!, _pending!, _current));
    } catch (error) {
      if (!_current()) return;
      final definite =
          error is ApiException &&
          [400, 401, 403, 404, 503].contains(error.statusCode);
      setState(() {
        _uncertain = !definite;
        _error = '$error';
        if (definite) {
          _pending = null;
          _preview = null;
          _request = null;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkStatus() async {
    if (_busy || !_current() || _pending == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await _repo.status(
        _shop!,
        _pending!['operationId'],
        _current,
      );
      if (!_current()) return;
      if (receipt != null) {
        _accept(receipt);
      } else {
        setState(() {
          _statusMissing = true;
          _error =
              'Chưa có biên nhận. Gửi lại cùng lượt hoặc đọc lại số liệu để đối chiếu; không tự cộng thêm chênh lệch cũ.';
        });
      }
    } catch (error) {
      if (_current()) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addObject() async {
    if (_busy || !_current()) return;
    final item = await showDialog<MapEntry<String, String>>(
      context: context,
      builder: (_) =>
          _OpeningObjectDialog(repo: _repo, shopId: _shop!, current: _current),
    );
    if (!_current() || item == null) return;
    setState(() => _keys[item.key] = item.value);
  }

  Future<void> _history() async {
    if (_busy || !_current()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _repo.history(_shop!, _current);
      if (!mounted || !_current()) return;
      final operationId = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Lượt khai gần đây của bạn'),
          content: SizedBox(
            width: 640,
            height: 360,
            child: (data['items'] as List).isEmpty
                ? const Center(child: Text('Chưa có lượt khai.'))
                : ListView(
                    children: [
                      for (final item in data['items'])
                        ListTile(
                          title: Text(
                            'Biên nhận #${item['batchId']} · Đầu ngày ${item['asOf']}',
                          ),
                          subtitle: Text(
                            '${item['adjustmentCount']} dòng thay đổi · ${item['sourceLinkCount'] ?? 0} nguồn liên kết',
                          ),
                          trailing: const AppIcon(Icons.chevron_right),
                          onTap: () => Navigator.pop(
                            dialogContext,
                            item['operationId'] as String,
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      if (operationId != null && _current()) {
        final receipt = await _repo.status(_shop, operationId, _current);
        if (_current() && receipt != null) _accept(receipt);
      }
    } catch (error) {
      if (_current()) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifySource(Map<String, dynamic> source) async {
    if (_busy || _uncertain || !_current()) return;
    try {
      final link = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _OpeningSourceDialog(source: source),
      );
      if (link == null || !_current()) return;
      _sourceLinks['${link['key']}:${link['debtId']}'] = link;
      await _read();
    } catch (error) {
      if (_current()) setState(() => _error = '$error');
    }
  }

  Widget _panel(Widget child) => AppCardContainer(
    padding: const EdgeInsets.all(20),
    child: Material(type: MaterialType.transparency, child: child),
  );
  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopProvider);
    ref.watch(authProvider);
    if (!_current()) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chọn một cửa hàng với quyền Chủ cửa hàng để khai số liệu ban đầu.',
          ),
        ),
      );
    }
    final locked = _busy || _uncertain || _receipt != null;
    return ListView(
      key: const Key('opening-scroll'),
      padding: const EdgeInsets.all(20),
      children: [
        AppPageHeader(
          title: 'Số liệu ban đầu',
          subtitle:
              '${shop.currentShopName ?? 'Cửa hàng #$_shop'} · Đối chiếu số đang có với sổ trong ứng dụng.',
          action: TextButton.icon(
            onPressed: _busy || _uncertain ? null : _history,
            icon: const AppIcon(Icons.history),
            label: const Text('Lịch sử khai'),
          ),
        ),
        const SizedBox(height: 16),
        _panel(
          const Text(
            'Khai số thực có ở đầu ngày được chọn, trước các giao dịch trong ngày. Ứng dụng chỉ ghi phần chênh lệch; không tạo thu nhập, chi phí hay khoản thanh toán giả. Đối tượng không chọn được giữ nguyên.',
          ),
        ),
        const SizedBox(height: 16),
        if (_snapshot == null)
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Chọn ngày và số liệu cần đối chiếu',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: min(
                    300,
                    max(0, MediaQuery.sizeOf(context).width - 80),
                  ),
                  child: BusinessDateField(
                    label: 'Ngày bắt đầu',
                    selectedDate: _date,
                    enabled: !_busy,
                    onChanged: (date) => setState(() => _date = date),
                  ),
                ),
                const SizedBox(height: 12),
                for (final wallet in const {
                  'cash': 'Tiền mặt',
                  'bank': 'Tiền gửi và chuyển khoản',
                }.entries)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(wallet.value),
                    value: _keys.containsKey(wallet.key),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              _keys[wallet.key] = wallet.value;
                            } else {
                              _keys.remove(wallet.key);
                            }
                          }),
                  ),
                for (final entry in _keys.entries.where(
                  (item) => !['cash', 'bank'].contains(item.key),
                ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    trailing: IconButton(
                      tooltip: 'Bỏ đối tượng',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _keys.remove(entry.key)),
                      icon: const AppIcon(Icons.close),
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy || _keys.length >= 500
                          ? null
                          : _addObject,
                      icon: const AppIcon(Icons.add),
                      label: const Text('Thêm hàng hoặc công nợ'),
                    ),
                    FilledButton(
                      onPressed: _busy || _keys.isEmpty ? null : _read,
                      child: const Text('Đọc số đã ghi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (_snapshot != null && _receipt == null) ...[
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Nhập số thực có · Đầu ngày ${DateFormat('dd/MM/yyyy').format(_date)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (!_snapshot!.storageReady)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Chức năng chưa được triển khai đủ trên máy chủ. Chỉ xem đối chiếu, chưa thể ghi.',
                    ),
                  ),
                if (_snapshot!.sourceCandidates.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Khoản nợ cần xác định ngày phát sinh',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Các khoản này đã có trong ứng dụng. Xác minh ngày thực tế để phân biệt nợ cũ và nợ phát sinh sau ngày khai, tránh ghi thêm một lần.',
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView(
                      primary: false,
                      shrinkWrap: true,
                      children: [
                        for (final source in _snapshot!.sourceCandidates)
                          _sourceTile(source, locked),
                      ],
                    ),
                  ),
                ],
                for (final row in _snapshot!.rows) _rowEditor(row, locked),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: locked ? null : _reset,
                      child: const Text('Chọn lại phạm vi'),
                    ),
                    OutlinedButton(
                      onPressed: locked ? null : _read,
                      child: const Text('Đọc lại số đã ghi'),
                    ),
                    FilledButton(
                      onPressed: locked || !_snapshot!.storageReady
                          ? null
                          : _showPreview,
                      child: const Text('Xem chênh lệch'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_preview != null) ...[
            const SizedBox(height: 16),
            _previewPanel(),
          ],
        ],
        if (_receipt != null) ...[
          const SizedBox(height: 16),
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã ghi · Biên nhận #${_receipt!.batchId}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText('Mã lượt: ${_receipt!.operationId}'),
                const SizedBox(height: 8),
                Text('Đầu ngày: ${_receipt!.plan['asOf']}'),
                const SizedBox(height: 12),
                _planRows(_receipt!.plan),
                const SizedBox(height: 12),
                const Text(
                  'Nếu cần sửa, hãy đối chiếu lại số thực có. Lượt mới chỉ ghi chênh lệch và giữ nguyên biên nhận này.',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _reset,
                  child: const Text('Đối chiếu lại'),
                ),
              ],
            ),
          ),
        ],
        if (_uncertain) ...[
          const SizedBox(height: 16),
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chưa xác nhận được kết quả. Không tạo lượt mới hoặc thay nội dung trước khi tra lại.',
                ),
                const SizedBox(height: 8),
                SelectableText('Mã lượt: ${_pending?['operationId']}'),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _busy ? null : _checkStatus,
                      child: const Text('Tra kết quả'),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _commit,
                      child: const Text('Gửi lại cùng lượt'),
                    ),
                    if (_statusMissing)
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() {
                                  _uncertain = false;
                                  _pending = null;
                                  _preview = null;
                                  _request = null;
                                  _statusMissing = false;
                                });
                                _read();
                              },
                        child: const Text('Đọc lại và đối chiếu'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sourceTile(Map<String, dynamic> source, bool locked) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_snapshot!.label(source['key'])} · Khoản #${source['debtId']}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Số gốc: ${NumberFormat('#,##0.##', 'vi_VN').format(num.parse('${source['amount']}'))} đ · Đã thanh toán: ${NumberFormat('#,##0.##', 'vi_VN').format(num.parse('${source['paidAmount']}'))} đ\nNhập vào ứng dụng: ${source['recordedDate']}${source['businessDate'] == null ? '' : '\nĐã xác minh phát sinh: ${source['businessDate']}'}',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: locked ? null : () => _verifySource(source),
            child: Text(
              source['businessDate'] == null ? 'Xác minh' : 'Sửa nguồn',
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    ),
  );

  Widget _rowEditor(Map<String, dynamic> row, bool locked) {
    final key = row['key'] as String, stock = row['kind'] == 'STOCK';
    final debt = ['RECEIVABLE', 'PAYABLE'].contains(row['kind']);
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            Text(
              _snapshot!.label(key),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Đã ghi: ${stock ? row['quantity'] : NumberFormat('#,##0.##', 'vi_VN').format(num.parse(row['amount']))}${stock ? ' (số lượng)' : ' đ'}',
              ),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: min(280, constraints.maxWidth),
                  child: TextField(
                    key: ValueKey('opening-actual-$key'),
                    controller: _actual[key],
                    enabled: !locked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _changed(),
                    decoration: InputDecoration(
                      labelText: stock
                          ? 'Số lượng thực có'
                          : 'Số tiền thực có (đ)',
                      helperText: 'Nhập 0 nếu thực tế không còn',
                      helperMaxLines: 3,
                    ),
                  ),
                ),
                if (stock)
                  SizedBox(
                    width: min(280, constraints.maxWidth),
                    child: TextField(
                      key: ValueKey('opening-cost-$key'),
                      controller: _cost[key],
                      enabled: !locked,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => _changed(),
                      decoration: const InputDecoration(
                        labelText: 'Giá vốn một đơn vị (đ)',
                        helperText: 'Chỉ cần khi bổ sung hàng; được nhập 0',
                        helperMaxLines: 3,
                      ),
                    ),
                  ),
                if (debt)
                  OutlinedButton(
                    onPressed: locked
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2200),
                            );
                            if (picked != null && mounted) {
                              _dueDates[key] = DateFormat(
                                'yyyy-MM-dd',
                              ).format(picked);
                              _changed();
                            }
                          },
                    child: Text(
                      _dueDates[key] == null
                          ? 'Chọn hạn trả khi tăng nợ'
                          : 'Hạn trả: ${_dueDates[key]}',
                    ),
                  ),
              ],
            ),
            if (debt && _allocations[key]!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Nếu giảm nợ: nhập số giảm cho từng khoản dưới đây. Để 0 ở khoản giữ nguyên.',
              ),
              for (final item in (row['debts'] as List))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: min(400, constraints.maxWidth),
                    child: TextField(
                      key: ValueKey('opening-allocation-$key-${item['id']}'),
                      controller: _allocations[key]![item['id']],
                      enabled: !locked,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => _changed(),
                      decoration: InputDecoration(
                        labelText: 'Giảm khoản #${item['id']} (đ)',
                        helperText:
                            'Còn ${item['remaining']} đ; tối đa được giảm ${item['availableToAdjust']} đ',
                        helperMaxLines: 4,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planRows(Map<String, dynamic> plan) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 320),
    child: Scrollbar(
      child: SingleChildScrollView(
        primary: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final source in (plan['sourceLinks'] as List? ?? []))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Liên kết khoản #${source['debtId']} · Ngày phát sinh ${source['businessDate']}\nNguồn: ${source['reference']}\nGiữ nguyên khoản nợ và tiền đã thanh toán.',
                ),
              ),
            for (final row in (plan['rows'] as List))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${_snapshot?.label(row['key']) ?? _keys[row['key']] ?? row['key']}: ${_display(row['before'], row['kind'])} → ${_display(row['actual'], row['kind'])}\nChênh lệch: ${_display(row['delta'], row['kind'])}',
                ),
              ),
          ],
        ),
      ),
    ),
  );
  String _display(dynamic value, dynamic kind) => kind == 'STOCK'
      ? '$value đơn vị'
      : '${NumberFormat('#,##0.##', 'vi_VN').format((value as num) / 100)} đ';
  Widget _previewPanel() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. Kiểm tra trước khi ghi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        _planRows(_preview!.plan),
        for (final blocker in _preview!.blockers)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              blocker,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (!_preview!.canCommit && _preview!.blockers.isEmpty)
          const Text('Không có chênh lệch cần ghi.'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy || _uncertain || !_preview!.canCommit
              ? null
              : _commit,
          child: Text(
            _preview!.plan['adjustmentCount'] == 0 &&
                    (_preview!.plan['sourceLinkCount'] ?? 0) > 0
                ? 'Xác nhận liên kết nguồn'
                : 'Xác nhận ghi chênh lệch',
          ),
        ),
      ],
    ),
  );
}

class _OpeningSourceDialog extends StatefulWidget {
  final Map<String, dynamic> source;
  const _OpeningSourceDialog({required this.source});
  @override
  State<_OpeningSourceDialog> createState() => _OpeningSourceDialogState();
}

class _OpeningSourceDialogState extends State<_OpeningSourceDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _reference;
  DateTime? _date;
  @override
  void initState() {
    super.initState();
    _reference = TextEditingController(
      text: widget.source['reference']?.toString() ?? '',
    );
    _date = DateTime.tryParse(widget.source['businessDate']?.toString() ?? '');
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final recorded = DateTime.parse(widget.source['recordedDate']);
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime(now.year, now.month, now.day);
    final last = recorded.isBefore(today) ? recorded : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? last,
      firstDate: DateTime(1900),
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text('Xác minh khoản nợ #${widget.source['debtId']}'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Khoản nợ đã nhập vào ứng dụng ngày ${widget.source['recordedDate']}. Chọn ngày phát sinh thực tế theo sổ hoặc chứng từ, kể cả khi ngày đó nằm sau ngày khai số liệu ban đầu.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const AppIcon(Icons.calendar_today),
              label: Text(
                _date == null
                    ? 'Chọn ngày phát sinh thực tế'
                    : 'Ngày phát sinh: ${DateFormat('dd/MM/yyyy').format(_date!)}',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('opening-source-reference'),
              controller: _reference,
              maxLength: 300,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nguồn đối chiếu',
                hintText: 'Ví dụ: sổ công nợ trang 3, hóa đơn số…',
              ),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Ghi nguồn đối chiếu từ 3 ký tự'
                  : null,
            ),
            const SizedBox(height: 12),
            const Text(
              'Xác minh chỉ liên kết bản ghi đang có, không tạo thêm nợ hay khoản thanh toán. Sau khi đọc lại, kiểm tra và nhập số thực có trước khi xác nhận ghi.',
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
        onPressed: _date == null
            ? null
            : () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(context, {
                  'key': widget.source['key'],
                  'debtId': widget.source['debtId'],
                  'businessDate': DateFormat('yyyy-MM-dd').format(_date!),
                  'reference': _reference.text.trim(),
                });
              },
        child: const Text('Xác minh và đọc lại'),
      ),
    ],
  );
}

class _OpeningObjectDialog extends StatefulWidget {
  final OpeningBalanceRepository repo;
  final int shopId;
  final bool Function() current;
  const _OpeningObjectDialog({
    required this.repo,
    required this.shopId,
    required this.current,
  });
  @override
  State<_OpeningObjectDialog> createState() => _OpeningObjectDialogState();
}

class _OpeningObjectDialogState extends State<_OpeningObjectDialog> {
  final _search = TextEditingController();
  String _kind = 'STOCK';
  List<Map<String, dynamic>> _items = [], _warehouses = [];
  int? _warehouse;
  bool _loading = false;
  String? _error;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });
    try {
      final values = await Future.wait([
        widget.repo.options(widget.shopId, _kind, _search.text, widget.current),
        if (_kind == 'STOCK')
          widget.repo.warehouses(widget.shopId, widget.current),
      ]);
      if (!mounted || epoch != _epoch || !widget.current()) return;
      setState(() {
        _items = values[0];
        if (_kind == 'STOCK') {
          _warehouses = values[1];
          if (!_warehouses.any((row) => row['id'] == _warehouse)) {
            _warehouse = _warehouses.isEmpty ? null : _warehouses.first['id'];
          }
        }
      });
    } catch (error) {
      if (mounted && epoch == _epoch) setState(() => _error = '$error');
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thêm số liệu đối chiếu'),
    content: SizedBox(
      width: 640,
      height: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Nhóm số liệu'),
            items: const [
              DropdownMenuItem(value: 'STOCK', child: Text('Hàng theo kho')),
              DropdownMenuItem(
                value: 'RECEIVABLE',
                child: Text('Khách còn nợ'),
              ),
              DropdownMenuItem(
                value: 'PAYABLE',
                child: Text('Nợ nhà cung cấp'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _kind = value);
              _load();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Tìm tên hoặc mã',
              suffixIcon: IconButton(
                tooltip: 'Tìm kiếm',
                onPressed: _load,
                icon: const AppIcon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _load(),
          ),
          if (_kind == 'STOCK' && _warehouses.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              isExpanded: true,
              key: ValueKey('warehouse-$_warehouse'),
              initialValue: _warehouse,
              decoration: const InputDecoration(labelText: 'Kho đối chiếu'),
              items: _warehouses
                  .map(
                    (row) => DropdownMenuItem<int>(
                      value: row['id'],
                      child: Text('${row['name']}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _warehouse = value),
            ),
          ],
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('Không có kết quả phù hợp.'))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      return ListTile(
                        leading: _kind == 'STOCK'
                            ? ProductThumbnail(
                                imageUrl: item['imageUrl']?.toString(),
                                name: item['name']?.toString(),
                                size: 40,
                              )
                            : null,
                        title: Text('${item['name']}'),
                        subtitle: Text('${item['sku'] ?? item['code'] ?? ''}'),
                        enabled: _kind != 'STOCK' || _warehouse != null,
                        onTap: () {
                          if (!widget.current()) return;
                          final prefix = _kind == 'STOCK'
                              ? 'stock'
                              : _kind == 'RECEIVABLE'
                              ? 'customer'
                              : 'supplier';
                          final key =
                              '$prefix:${item['id']}${_kind == 'STOCK' ? ':$_warehouse' : ''}';
                          final warehouseName = _kind == 'STOCK'
                              ? ' · ${_warehouses.firstWhere((row) => row['id'] == _warehouse)['name']}'
                              : '';
                          Navigator.pop(
                            context,
                            MapEntry(key, '${item['name']}$warehouseName'),
                          );
                        },
                      );
                    },
                  ),
          ),
          const Text(
            'Hiển thị tối đa 20 kết quả. Tìm cụ thể hơn nếu chưa thấy đối tượng.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
  );
}
