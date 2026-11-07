import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_icon.dart';

String _money(dynamic value) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
).format(num.tryParse('$value') ?? 0);
String _date(dynamic value) {
  final date = DateTime.tryParse('$value');
  return date == null ? '$value' : DateFormat('dd/MM/yyyy').format(date);
}

Future<void> showCashflowDailyDetails(BuildContext context, Map projection) =>
    showDialog<void>(
      context: context,
      builder: (_) => CashflowDailyDetails(projection: projection),
    );

class CashflowDailyDetails extends StatelessWidget {
  final Map projection;
  const CashflowDailyDetails({super.key, required this.projection});
  @override
  Widget build(BuildContext context) {
    final days = (projection['daily'] as List? ?? []).whereType<Map>().toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 860,
        height: MediaQuery.sizeOf(context).height * .85,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cách tính dự báo theo ngày',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const AppIcon(Icons.close),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Số dư theo sổ đến ${_date(projection['asOf'])}: ${_money(projection['bookBalance'])}',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Số dư cuối ngày = số dư đầu ngày + thu dự kiến − chi dự kiến. Công nợ theo hạn đã ghi; kế hoạch bổ sung chỉ gồm khoản chưa có trong công nợ. Đây là số dự kiến, chưa ghi thu/chi thực tế.',
              ),
              const Divider(height: 24),
              Expanded(
                child: days.isEmpty
                    ? const Center(child: Text('Chưa có chi tiết dự báo.'))
                    : ListView.separated(
                        itemCount: days.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final day = days[index];
                          final opening = index == 0
                              ? projection['bookBalance']
                              : days[index - 1]['balance'];
                          final fields = <String, dynamic>{
                            'Số dư đầu ngày': opening,
                            'Thu từ công nợ đến hạn': day['receivableIncome'],
                            'Thu theo kế hoạch bổ sung': day['plannedIncome'],
                            'Chi trả công nợ đến hạn': day['payableExpense'],
                            'Chi theo kế hoạch bổ sung': day['plannedExpense'],
                            'Số dư cuối ngày dự kiến': day['balance'],
                          };
                          return ExpansionTile(
                            key: ValueKey(day['date']),
                            tilePadding: EdgeInsets.zero,
                            title: Text(_date(day['date'])),
                            subtitle: Text(
                              'Thu ${_money(day['income'])} · Chi ${_money(day['expense'])}\nCuối ngày ${_money(day['balance'])}',
                            ),
                            children: fields.entries
                                .map(
                                  (field) => Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      right: 12,
                                      bottom: 12,
                                    ),
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        Text('${field.key}:'),
                                        SelectableText(_money(field.value)),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
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
}
