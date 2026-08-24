import 'package:flutter_app/features/finance/presentation/debt_aging_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debt aging switches to cards only on compact widths', () {
    expect(debtAgingUsesMobileCards(390), isTrue);
    expect(debtAgingUsesMobileCards(719), isTrue);
    expect(debtAgingUsesMobileCards(720), isFalse);
    expect(debtAgingUsesMobileCards(1280), isFalse);
  });

  test('debt aging customers only uses database response rows', () {
    final customers = debtAgingCustomers({
      'customers': [
        {
          'customerId': 10,
          'customerName': 'Công ty Minh Việt',
          'total': 12000000,
          'overdue': 8000000,
        },
        'invalid-row',
      ],
    });

    expect(customers, hasLength(1));
    expect(customers.single['customerId'], 10);
    expect(customers.single['overdue'], 8000000);
    expect(debtAgingCustomers(const {}), isEmpty);
  });
}
