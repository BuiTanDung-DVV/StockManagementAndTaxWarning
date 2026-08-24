import 'package:flutter_app/features/sales/presentation/customer_debt_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debt overview counts unique customers instead of receivable rows', () {
    final overview = customerDebtOverview([
      {
        'id': 1,
        'customerId': 10,
        'totalAmount': 1000000,
        'paidAmount': 200000,
        'remaining': 800000,
        'daysOverdue': 5,
      },
      {
        'id': 2,
        'customerId': 10,
        'totalAmount': 500000,
        'paidAmount': 0,
        'remaining': 500000,
        'daysOverdue': 0,
      },
      {
        'id': 3,
        'customerId': 11,
        'totalAmount': 300000,
        'paidAmount': 0,
        'remaining': 300000,
        'status': 'OVERDUE',
      },
    ]);

    expect(overview.receivableCount, 3);
    expect(overview.customerCount, 2);
    expect(overview.outstanding, 1600000);
    expect(overview.overdue, 1100000);
  });

  test('debt UI prioritizes authoritative remaining and due status', () {
    expect(
      customerDebtRemaining({
        'totalAmount': 1000000,
        'paidAmount': 100000,
        'remaining': 750000,
      }),
      750000,
    );
    expect(customerDebtDueLabel({'daysOverdue': 12}), 'Quá hạn 12 ngày');
    expect(
      customerDebtDueLabel({'dueDate': '2026-08-25', 'daysOverdue': 0}),
      'Hạn 25/08/2026',
    );
  });

  test('debt collection routes linked and manual receivables correctly', () {
    expect(customerDebtPaymentTarget({'id': 11, 'orderId': 99}), (
      orderId: 99,
      receivableId: 11,
    ));
    expect(customerDebtPaymentTarget({'id': 12, 'orderId': null}), (
      orderId: 0,
      receivableId: 12,
    ));
    expect(
      () => customerDebtPaymentTarget({'id': null, 'orderId': null}),
      throwsFormatException,
    );
  });

  test('debt list query sends only active server-side filters', () {
    expect(
      customerDebtListQuery(
        page: 3,
        limit: 20,
        search: '  Kiến Tạo  ',
        status: 'OVERDUE',
        sort: 'REMAINING_DESC',
      ),
      {
        'page': 3,
        'limit': 20,
        'status': 'OVERDUE',
        'sort': 'REMAINING_DESC',
        'search': 'Kiến Tạo',
      },
    );
    expect(customerDebtListQuery().containsKey('search'), isFalse);
  });
}
