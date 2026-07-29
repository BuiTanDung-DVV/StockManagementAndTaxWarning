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
