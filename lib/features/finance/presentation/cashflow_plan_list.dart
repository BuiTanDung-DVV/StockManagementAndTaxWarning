import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_icon.dart';

class CashflowPlanList extends StatefulWidget {
  final List plans;
  final String asOf;
  final String throughDate;
  final ValueChanged<int> onDelete;
  const CashflowPlanList({
    super.key,
    required this.plans,
    required this.asOf,
    required this.throughDate,
    required this.onDelete,
  });
  @override
  State<CashflowPlanList> createState() => _CashflowPlanListState();
}

class _CashflowPlanListState extends State<CashflowPlanList> {
  String _range = 'period';
  String _day(Map plan) => '${plan['forecastDate']}'.split('T').first;
  String _money(dynamic value) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(num.tryParse('$value') ?? 0);
  @override
  Widget build(BuildContext context) {
    final plans =
        widget.plans
            .whereType<Map>()
            .where(
              (p) =>
                  _range == 'all' ||
                  (_range == 'past'
                      ? _day(p).compareTo(widget.asOf) <= 0
                      : _day(p).compareTo(widget.asOf) > 0 &&
                            _day(p).compareTo(widget.throughDate) <= 0),
            )
            .toList()
          ..sort((a, b) => _day(a).compareTo(_day(b)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _range,
                decoration: const InputDecoration(
                  labelText: 'Phạm vi kế hoạch',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'period',
                    child: Text('Trong kỳ dự báo'),
                  ),
                  DropdownMenuItem(
                    value: 'past',
                    child: Text('Đã qua ngày dự kiến'),
                  ),
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Tất cả thời gian'),
                  ),
                ],
                onChanged: (v) => setState(() => _range = v ?? 'period'),
              ),
            ),
            Text('${plans.length}/${widget.plans.length} kế hoạch'),
          ],
        ),
        const SizedBox(height: 12),
        if (plans.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chưa có kế hoạch bổ sung trong phạm vi này.'),
          )
        else
          SizedBox(
            height: 320,
            child: Scrollbar(
              child: ListView.separated(
                primary: false,
                itemCount: plans.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final p = plans[index];
                  final date = DateTime.tryParse(_day(p));
                  return ListTile(
                    title: Text(
                      date == null
                          ? _day(p)
                          : DateFormat('dd/MM/yyyy').format(date),
                    ),
                    subtitle: Text(
                      'Thu ${_money(p['expectedIncome'])} · Chi ${_money(p['expectedExpense'])}${_day(p).compareTo(widget.asOf) <= 0
                          ? '\nĐã qua ngày dự kiến, không cộng vào kỳ tới.'
                          : _day(p).compareTo(widget.throughDate) > 0
                          ? '\nNgoài kỳ dự báo đang xem.'
                          : ''}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Xóa kế hoạch bổ sung',
                      icon: const AppIcon(Icons.delete_outline),
                      onPressed: () => widget.onDelete(int.parse('${p['id']}')),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
