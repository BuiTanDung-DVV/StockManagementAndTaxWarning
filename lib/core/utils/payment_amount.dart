String parsePaymentAmount(String input) {
  var text = input.trim().replaceAll(' ', '');
  if (RegExp(r'^[1-9]\d{0,2}(\.\d{3})+(,\d{1,2})?$').hasMatch(text)) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d+(,\d{1,2})?$').hasMatch(text)) {
    text = text.replaceAll(',', '.');
  } else if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
    throw const FormatException(
      'Nhập số tiền hợp lệ, tối đa hai chữ số phần lẻ',
    );
  }
  final parts = text.split('.');
  final cents =
      BigInt.parse(parts[0]) * BigInt.from(100) +
      BigInt.parse(parts.length == 1 ? '00' : parts[1].padRight(2, '0'));
  if (cents <= BigInt.zero || cents > BigInt.parse('999999999999999')) {
    throw const FormatException('Số tiền ngoài giới hạn cho phép');
  }
  return '${cents ~/ BigInt.from(100)}.${(cents % BigInt.from(100)).toString().padLeft(2, '0')}';
}
