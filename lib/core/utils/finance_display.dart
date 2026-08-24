import 'package:intl/intl.dart';

final _vietnameseIntegerFormat = NumberFormat.decimalPattern('vi_VN');

String formatVietnameseCurrency(num value) =>
    '${_vietnameseIntegerFormat.format(value.round())} ₫';

String financeCategoryLabel(String? category) {
  switch (category?.trim().toUpperCase()) {
    case 'PURCHASE':
      return 'Mua hàng';
    case 'SALARY':
      return 'Lương nhân viên';
    case 'RENT':
      return 'Tiền thuê mặt bằng';
    case 'SALES_RETURN':
      return 'Hoàn tiền hàng bán';
    case 'UTILITIES':
      return 'Điện, nước và tiện ích';
    case 'DELIVERY':
      return 'Giao nhận và bốc xếp';
    case 'CAPITAL':
      return 'Vốn góp';
    case 'LOAN':
      return 'Khoản vay';
    case 'SALES':
      return 'Doanh thu bán hàng';
    case 'DEBT_COLLECTION':
      return 'Thu công nợ';
    case 'OTHER':
    case null:
    case '':
      return 'Khác';
    default:
      return category!.trim();
  }
}

String financePaymentMethodLabel(String? method) {
  switch (method?.trim().toUpperCase()) {
    case 'CASH':
      return 'Tiền mặt';
    case 'TRANSFER':
    case 'BANK_TRANSFER':
      return 'Chuyển khoản';
    case 'QR':
    case 'QR_CODE':
      return 'QR ngân hàng';
    case 'CARD':
    case 'CREDIT_CARD':
      return 'Thẻ';
    case 'MOMO':
      return 'MoMo';
    case 'ZALOPAY':
      return 'ZaloPay';
    case null:
    case '':
      return 'Tiền mặt';
    default:
      return method!.trim();
  }
}

String financeTransactionDescription(Map<dynamic, dynamic> transaction) {
  for (final key in const ['notes', 'description', 'note']) {
    final value = transaction[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }

  final category = transaction['category']?.toString();
  if (category != null && category.trim().isNotEmpty) {
    return financeCategoryLabel(category);
  }
  final type = transaction['type']?.toString().toUpperCase();
  return type == 'INCOME' ? 'Giao dịch thu' : 'Giao dịch chi';
}

String? financeTransactionDateValue(Map<dynamic, dynamic> transaction) {
  for (final key in const ['transactionDate', 'date', 'createdAt']) {
    final value = transaction[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

bool financeTransactionIsLinked(Map<dynamic, dynamic> transaction) {
  final referenceType = transaction['referenceType']?.toString().trim();
  return referenceType != null &&
      referenceType.isNotEmpty &&
      referenceType != 'CASH_TRANSACTION';
}
