import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/search_text.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../customers/providers/customer_provider.dart';
import '../../settings/providers/shop_provider.dart';

String agingBucket(Map row) {
  final days = asInt(row['daysOverdue']);
  return days <= 0
      ? 'current'
      : days <= 30
      ? 'past30'
      : days <= 60
      ? 'past60'
      : 'past90';
}

const agingBucketLabels = <String, String>{
  'ALL': 'Tất cả khoản nợ',
  'OVERDUE': 'Đã quá hạn',
  'current': 'Chưa đến hạn',
  'past30': 'Quá hạn 1–30 ngày',
  'past60': 'Quá hạn 31–60 ngày',
  'past90': 'Quá hạn trên 60 ngày',
};
String _money(dynamic value) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 2,
).format(asDouble(value)).replaceFirst(RegExp(r',00(?=\s*₫)'), '');
String _date(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  return parsed == null
      ? 'Chưa ghi'
      : DateFormat('dd/MM/yyyy').format(parsed.toLocal());
}

String _name(Map row, bool payable) =>
    '${row[payable ? 'supplierName' : 'customerName'] ?? 'Chưa xác định'}';

Future<void> showAgingDebtExplorer(
  BuildContext context, {
  required bool payable,
  List<Map<String, dynamic>>? rows,
  String bucket = 'ALL',
  int? partyId,
}) async {
  final route = await showDialog<String>(
    context: context,
    builder: (_) => _AgingExplorer(
      payable: payable,
      rows: rows,
      bucket: bucket,
      partyId: partyId,
    ),
  );
  if (route != null && context.mounted) await context.push(route);
}

Future<void> showAgingDebtDetail(
  BuildContext context,
  Map<String, dynamic> row, {
  required bool payable,
}) async {
  final route = await showDialog<String>(
    context: context,
    builder: (_) => _DebtDetail(row: row, payable: payable),
  );
  if (route != null && context.mounted) await context.push(route);
}

class _AgingExplorer extends ConsumerStatefulWidget {
  final bool payable;
  final List<Map<String, dynamic>>? rows;
  final String bucket;
  final int? partyId;
  const _AgingExplorer({
    required this.payable,
    this.rows,
    required this.bucket,
    this.partyId,
  });
  @override
  ConsumerState<_AgingExplorer> createState() => _AgingExplorerState();
}

class _AgingExplorerState extends ConsumerState<_AgingExplorer> {
  Future<List<Map<String, dynamic>>>? _future;
  late final int? _shopId;
  @override
  void initState() {
    super.initState();
    _shopId = ref.read(shopProvider).currentShopId;
    _load();
  }

  void _load() {
    bool current() =>
        mounted &&
        ref.read(shopProvider).currentShopId == _shopId &&
        !ref.read(shopProvider).isAllShops;
    _future = widget.rows != null
        ? Future.value(widget.rows!)
        : _shopId == null
        ? Future.error(StateError('Chọn một cửa hàng trước khi xem.'))
        : ref
              .read(customerRepoProvider)
              .exportOpenReceivablesInShop(
                _shopId!,
                params: {
                  'asOf': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'status': 'ALL',
                },
                isCurrentScope: current,
              )
              .then(
                (rows) => rows
                    .whereType<Map>()
                    .map((row) => Map<String, dynamic>.from(row))
                    .toList(),
              );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    clipBehavior: Clip.antiAlias,
    insetPadding: const EdgeInsets.all(20),
    child: SizedBox(
      width: 1100,
      height: MediaQuery.sizeOf(context).height * .85,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.payable
                        ? 'Chi tiết khoản phải trả'
                        : 'Chi tiết khoản phải thu',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const AppIcon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ref.watch(shopProvider).currentShopId != _shopId
                  ? const Center(
                      child: Text(
                        'Cửa hàng đã thay đổi. Đóng và mở lại báo cáo.',
                      ),
                    )
                  : FutureBuilder<List<Map<String, dynamic>>>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        if (snapshot.hasError)
                          return Center(
                            child: OutlinedButton(
                              onPressed: () => setState(_load),
                              child: const Text(
                                'Chưa tải được các khoản nợ · Thử lại',
                              ),
                            ),
                          );
                        return AgingDebtTable(
                          rows: snapshot.data ?? [],
                          payable: widget.payable,
                          initialBucket: widget.bucket,
                          initialPartyId: widget.partyId,
                          bounded: true,
                          onOpen: (row) async {
                            final route = await showDialog<String>(
                              context: context,
                              builder: (_) => _DebtDetail(
                                row: row,
                                payable: widget.payable,
                              ),
                            );
                            if (route != null && context.mounted)
                              Navigator.pop(context, route);
                          },
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

class AgingDebtTable extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final bool payable, bounded;
  final String initialBucket;
  final int? initialPartyId;
  final ValueChanged<Map<String, dynamic>>? onOpen;
  const AgingDebtTable({
    super.key,
    required this.rows,
    required this.payable,
    this.bounded = false,
    this.initialBucket = 'ALL',
    this.initialPartyId,
    this.onOpen,
  });
  @override
  State<AgingDebtTable> createState() => _AgingDebtTableState();
}

class _AgingDebtTableState extends State<AgingDebtTable> {
  final _search = TextEditingController();
  late String _bucket;
  int? _partyId;
  int _page = 1;
  @override
  void initState() {
    super.initState();
    _bucket = widget.initialBucket;
    _partyId = widget.initialPartyId;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows.where((row) {
      final party = asInt(row[widget.payable ? 'supplierId' : 'customerId']);
      final bucket = agingBucket(row);
      return (_partyId == null || party == _partyId) &&
          (_bucket == 'ALL' ||
              _bucket == bucket ||
              (_bucket == 'OVERDUE' && bucket != 'current')) &&
          foldSearchText(
            '${_name(row, widget.payable)} ${row['orderCode'] ?? ''} ${row['id']}',
          ).contains(foldSearchText(_search.text));
    }).toList();
    final pages = ((rows.length + 9) ~/ 10).clamp(1, 100000);
    final page = _page.clamp(1, pages);
    final visible = rows.skip((page - 1) * 10).take(10).toList();
    void open(Map<String, dynamic> row) {
      if (widget.onOpen != null) {
        widget.onOpen!(row);
      } else {
        showAgingDebtDetail(context, row, payable: widget.payable);
      }
    }

    final table = AppDataTable<Map<String, dynamic>>(
      showSearch: false,
      title: widget.payable ? 'Các khoản phải trả' : 'Các khoản phải thu',
      assetPath: AppAssets.cash,
      headerAction: Text('${rows.length}/${widget.rows.length} khoản'),
      columns: const [
        AppDataTableColumn(title: 'ĐỐI TÁC', flex: 4),
        AppDataTableColumn(title: 'HẠN TRẢ', flex: 2),
        AppDataTableColumn(title: 'ĐÃ THU/TRẢ', flex: 2, alignRight: true),
        AppDataTableColumn(title: 'CÒN LẠI', flex: 2, alignRight: true),
        AppDataTableColumn(title: '', flex: 1),
      ],
      items: visible,
      rowBuilder: (context, row, index) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => open(row),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 660)
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name(row, widget.payable),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '#${row['id']} · Hạn ${_date(row['dueDate'])}',
                            ),
                            Text(agingBucketLabels[agingBucket(row)]!),
                            Text(
                              'Còn ${_money(row['remaining'])}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const AppIcon(Icons.chevron_right, size: 18),
                    ],
                  );
                return Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name(row, widget.payable),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '#${row['id']} · ${agingBucketLabels[agingBucket(row)]}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Expanded(flex: 2, child: Text(_date(row['dueDate']))),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _money(row['paidAmount']),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _money(row['remaining']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AppIcon(Icons.chevron_right, size: 18),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      emptyMessage: 'Không có khoản nợ khớp bộ lọc.',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() => _page = 1),
                decoration: const InputDecoration(
                  labelText: 'Tìm đối tác hoặc mã khoản nợ',
                  prefixIcon: AppIcon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String>(
                key: ValueKey(_bucket),
                initialValue: _bucket,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nhóm tuổi nợ'),
                items: agingBucketLabels.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _bucket = value ?? 'ALL';
                  _page = 1;
                }),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _search.clear();
                _bucket = 'ALL';
                _partyId = null;
                _page = 1;
              }),
              icon: const AppIcon(Icons.filter_alt_off_outlined),
              label: const Text('Bỏ lọc'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.bounded)
          Expanded(child: SingleChildScrollView(child: table))
        else
          table,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Trang $page/$pages'),
            IconButton(
              tooltip: 'Trang trước',
              onPressed: page > 1
                  ? () => setState(() => _page = page - 1)
                  : null,
              icon: const AppIcon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Trang sau',
              onPressed: page < pages
                  ? () => setState(() => _page = page + 1)
                  : null,
              icon: const AppIcon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class _DebtDetail extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool payable;
  const _DebtDetail({required this.row, required this.payable});
  @override
  Widget build(BuildContext context) {
    final party = asInt(row[payable ? 'supplierId' : 'customerId']);
    final source = asInt(row[payable ? 'purchaseOrderId' : 'orderId']);
    final fields = <String, String>{
      payable ? 'Nhà cung cấp' : 'Khách hàng': _name(row, payable),
      'Ngày phát sinh': _date(row['createdAt']),
      'Hạn thanh toán': _date(row['dueDate']),
      'Nhóm tuổi nợ': agingBucketLabels[agingBucket(row)]!,
      'Giá trị ghi nợ': _money(row['amount'] ?? row['totalAmount']),
      payable ? 'Đã trả' : 'Đã thu': _money(row['paidAmount']),
      if (asDouble(row['openingAdjustmentAmount']) != 0)
        'Điều chỉnh số dư đầu kỳ': _money(row['openingAdjustmentAmount']),
      'Còn phải thanh toán': _money(row['remaining']),
      if (source > 0) 'Chứng từ nguồn': '${row['orderCode'] ?? '#$source'}',
    };
    return AlertDialog(
      title: Text('Khoản ${payable ? 'phải trả' : 'phải thu'} #${row['id']}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.key,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      SelectableText(field.value),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        if (party > 0 && GoRouter.maybeOf(context) != null)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              '/${payable ? 'suppliers' : 'customers'}/$party',
            ),
            child: Text(payable ? 'Hồ sơ NCC' : 'Hồ sơ khách hàng'),
          ),
        if (source > 0 && GoRouter.maybeOf(context) != null)
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              payable ? '/purchase-orders/detail?id=$source' : '/sales/$source',
            ),
            child: const Text('Mở chứng từ nguồn'),
          ),
      ],
    );
  }
}
