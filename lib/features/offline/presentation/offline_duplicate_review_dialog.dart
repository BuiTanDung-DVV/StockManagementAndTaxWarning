import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/utils/finance_display.dart';

/// Choosing a source is explicit. The server still rechecks this snapshot under
/// its write lock; displaying this dialog never approves the operation itself.
class OfflineDuplicateReviewDialog extends StatelessWidget {
  final OfflineOperation operation;
  const OfflineDuplicateReviewDialog({super.key, required this.operation});

  @override
  Widget build(BuildContext context) {
    final review = operation.value['review'] as Map;
    final candidates = (review['candidates'] as List).cast<Map>();
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    String amount(dynamic value) => money.format(num.tryParse('$value') ?? 0);
    String date(dynamic value) {
      final parsed = DateTime.tryParse('$value');
      return parsed == null
          ? 'Chưa ghi ngày'
          : DateFormat('dd/MM/yyyy').format(parsed);
    }

    String payment(dynamic value) => value == 'DEBT'
        ? 'Ghi nợ'
        : financePaymentMethodLabel(value?.toString());
    final names = <String, String>{
      for (final candidate in candidates)
        for (final line
            in candidate['items'] is List
                ? candidate['items'] as List
                : const [])
          if (line['productId'] != null && line['name'] != null)
            '${line['productId']}': '${line['name']}',
    };
    void choose(String action, [int? id]) =>
        Navigator.pop(context, <String, dynamic>{
          'guard': review['guard'],
          'action': action,
          'entityId': ?id,
        });
    return AlertDialog(
      title: const Text('Kiểm tra trước khi ghi thêm'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cửa hàng có giao dịch tương tự. Cùng ngày hoặc số tiền chưa đủ để kết luận là trùng.',
              ),
              const SizedBox(height: 12),
              Text(
                'Ghi chép trên thiết bị · ${date(operation.payload['transactionDate'] ?? operation.payload['orderDate'])}',
              ),
              if (operation.payload['amount'] != null)
                Text('Số tiền: ${amount(operation.payload['amount'])}'),
              if (operation.payload['counterparty'] != null)
                Text('${operation.payload['counterparty']}'),
              if (operation.payload['notes'] != null)
                Text('${operation.payload['notes']}'),
              if (operation.payload['paymentMethod'] != null)
                Text(
                  'Cách ghi: ${payment(operation.payload['paymentMethod'])}',
                ),
              for (final line
                  in operation.payload['items'] is List
                      ? operation.payload['items'] as List
                      : const [])
                Text(
                  '${names['${line['productId']}'] ?? 'Mặt hàng #${line['productId']}'} × ${line['quantity']} · ${amount(line['unitPrice'])}',
                ),
              const SizedBox(height: 16),
              const Text(
                'Giao dịch đã có trên cửa hàng',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final candidate in candidates) ...[
                const Divider(height: 24),
                Text(
                  '${candidate['code']} · ${date(candidate['date'])}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${amount(candidate['amount'])} · ${candidate['counterparty'] ?? 'Chưa ghi đối tác'}',
                ),
                if (candidate['invoiceNumber'] != null)
                  Text('Chứng từ nguồn: ${candidate['invoiceNumber']}'),
                if (candidate['notes'] != null) Text('${candidate['notes']}'),
                if (candidate['paymentMethod'] != null)
                  Text('Cách ghi: ${payment(candidate['paymentMethod'])}'),
                if (candidate['paidAmount'] != null)
                  Text('Đã thanh toán: ${amount(candidate['paidAmount'])}'),
                for (final line
                    in candidate['items'] is List
                        ? candidate['items'] as List
                        : const [])
                  Text(
                    '${line['name'] ?? 'Mặt hàng'} × ${line['quantity']} · ${amount(line['unitPrice'])}',
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        choose('useExisting', candidate['id'] as int),
                    child: Text('Dùng giao dịch ${candidate['code']}'),
                  ),
                ),
              ],
              if (candidates.isEmpty)
                const Text(
                  'Dữ liệu đã thay đổi. Kiểm tra lại ghi chép trước khi xác nhận.',
                ),
              if (review['truncated'] == true)
                const Text(
                  'Đang hiển thị 20 giao dịch gần nhất có dấu hiệu tương tự.',
                ),
              const SizedBox(height: 12),
              const Text(
                'Dùng giao dịch đã có sẽ liên kết ghi chép này, không cộng thêm tiền, kho hoặc công nợ. Chỉ chọn ghi thêm nếu đây là nghiệp vụ khác.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Để kiểm tra sau'),
        ),
        OutlinedButton(
          onPressed: () => choose('createNew'),
          child: const Text('Đây là giao dịch khác, ghi thêm'),
        ),
      ],
    );
  }
}
