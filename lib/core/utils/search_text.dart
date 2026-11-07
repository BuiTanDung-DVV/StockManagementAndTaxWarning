/// Match Vietnamese names consistently for locally filtered records.
String foldSearchText(Object? value) {
  var text = (value?.toString() ?? '').trim().toLowerCase();
  const groups = {
    'a': 'áàảãạăắằẳẵặâấầẩẫậ',
    'e': 'éèẻẽẹêếềểễệ',
    'i': 'íìỉĩị',
    'o': 'óòỏõọôốồổỗộơớờởỡợ',
    'u': 'úùủũụưứừửữự',
    'y': 'ýỳỷỹỵ',
    'd': 'đ',
  };
  groups.forEach((plain, accents) {
    for (final rune in accents.runes) {
      text = text.replaceAll(String.fromCharCode(rune), plain);
    }
  });
  return text.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
}

/// Include related names supplied as nested API records, such as supplier.name.
String recordSearchText(Object? value) {
  if (value is Map) return value.values.map(recordSearchText).join(' ');
  if (value is Iterable) return value.map(recordSearchText).join(' ');
  return value is String || value is num ? foldSearchText(value) : '';
}
