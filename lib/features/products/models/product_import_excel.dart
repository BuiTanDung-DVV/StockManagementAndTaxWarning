import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

// Read OOXML values rather than rendered text or cached formula results.
// Namespace prefixes and workbook-relative/absolute paths are both supported.
class ProductImportWorkbook {
  final Archive _archive;
  final Map<String, String> _sheets;
  final List<String> _strings;
  final List<bool> _dateStyles;
  ProductImportWorkbook._(
    this._archive,
    this._sheets,
    this._strings,
    this._dateStyles,
  );

  factory ProductImportWorkbook.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const FormatException(
        'File Excel phải có dữ liệu và không vượt quá 5 MB.',
      );
    }
    try {
      final directory = ZipDirectory()..read(InputMemoryStream(bytes));
      if (directory.fileHeaders.isEmpty || directory.fileHeaders.length > 250) {
        throw const FormatException(
          'File Excel quá phức tạp. Hãy dùng file mẫu của SmartStock.',
        );
      }
      var expanded = 0;
      for (final entry in directory.fileHeaders) {
        expanded += entry.uncompressedSize;
        if (expanded > 8 * 1024 * 1024 ||
            entry.generalPurposeBitFlag & 1 != 0) {
          throw const FormatException(
            'File Excel quá lớn sau giải nén hoặc được đặt mật khẩu.',
          );
        }
      }
      final archive = ZipDecoder().decodeBytes(bytes);
      final workbook = _document(archive, 'xl/workbook.xml'),
          relationships = _document(archive, 'xl/_rels/workbook.xml.rels');
      final targets = <String, String>{};
      String? stringPath, stylePath;
      for (final rel in _elements(relationships, 'Relationship')) {
        if (rel.getAttribute('TargetMode') == 'External') continue;
        final target = rel.getAttribute('Target'), id = rel.getAttribute('Id');
        if (target == null || id == null) continue;
        final uri = Uri.parse(
          'xl/workbook.xml',
        ).resolve(target).normalizePath();
        final resolved = uri.path.replaceFirst(RegExp(r'^/'), '');
        if (uri.hasScheme || !resolved.startsWith('xl/')) continue;
        targets[id] = resolved;
        if (rel.getAttribute('Type')?.endsWith('/sharedStrings') == true) {
          stringPath = resolved;
        }
        if (rel.getAttribute('Type')?.endsWith('/styles') == true) {
          stylePath = resolved;
        }
      }
      final sheets = <String, String>{};
      for (final sheet in _elements(workbook, 'sheet')) {
        if (['hidden', 'veryHidden'].contains(sheet.getAttribute('state'))) {
          continue;
        }
        final name = sheet.getAttribute('name'),
            ids = sheet.attributes.where((a) => a.name.local == 'id');
        final target = ids.isEmpty ? null : targets[ids.first.value];
        if (name == null || target == null || sheets.containsKey(name)) {
          throw const FormatException('Thông tin sheet không hợp lệ.');
        }
        sheets[name] = target;
      }
      if (sheets.isEmpty || sheets.length > 20) {
        throw const FormatException('File cần có từ 1 đến 20 sheet hiển thị.');
      }
      final strings = <String>[];
      if (stringPath != null) {
        for (final item in _elements(_document(archive, stringPath), 'si')) {
          strings.add(_text(item));
        }
      }
      final dateStyles = <bool>[];
      if (stylePath != null) {
        final styles = _document(archive, stylePath);
        final formats = {
          for (final format in _elements(styles, 'numFmt'))
            format.getAttribute('numFmtId'):
                format.getAttribute('formatCode') ?? '',
        };
        final xfs = _elements(styles, 'cellXfs');
        if (xfs.isNotEmpty) {
          for (final xf in xfs.first.childElements.where(
            (e) => e.name.local == 'xf',
          )) {
            final id = int.tryParse(xf.getAttribute('numFmtId') ?? '0') ?? 0;
            final code = (formats['$id'] ?? '').replaceAll(
              RegExp(r'"[^"]*"|\\.|\[[^\]]*\]'),
              '',
            );
            dateStyles.add(
              (id >= 14 && id <= 22) ||
                  (id >= 27 && id <= 36) ||
                  (id >= 45 && id <= 47) ||
                  (id >= 50 && id <= 58) ||
                  RegExp('[ymdhs]', caseSensitive: false).hasMatch(code),
            );
          }
        }
      }
      return ProductImportWorkbook._(archive, sheets, strings, dateStyles);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Không đọc được file Excel. Hãy mở và lưu lại dưới dạng .xlsx.',
      );
    }
  }

  List<String> get sheets => _sheets.keys.toList(growable: false);
  String get defaultSheet =>
      _sheets.containsKey('San pham') ? 'San pham' : sheets.first;
  String csvForSheet(String name) {
    final path = _sheets[name];
    if (path == null) {
      throw const FormatException('Sheet đã chọn không tồn tại.');
    }
    final sheet = _document(_archive, path), values = <int, Map<int, String>>{};
    var height = 0, width = 0, rowPosition = 0;
    for (final row in _elements(sheet, 'row')) {
      rowPosition =
          int.tryParse(row.getAttribute('r') ?? '') ?? rowPosition + 1;
      var column = 0;
      for (final cell in row.childElements.where((e) => e.name.local == 'c')) {
        final reference = cell.getAttribute('r');
        var rowNumber = rowPosition;
        if (reference != null) {
          final match = RegExp(r'^([A-Z]+)([1-9]\d*)$').firstMatch(reference);
          if (match == null) {
            throw const FormatException('Địa chỉ ô Excel không hợp lệ.');
          }
          column = 0;
          for (final code in match[1]!.codeUnits) {
            column = column * 26 + code - 64;
          }
          rowNumber = int.parse(match[2]!);
        } else {
          column++;
        }
        final coordinate = reference ?? '$column:$rowNumber';
        if (cell.childElements.any((e) => e.name.local == 'f')) {
          throw FormatException(
            'Ô $coordinate chứa công thức. Hãy dán giá trị trước khi nhập.',
          );
        }
        final v = cell.childElements.where((e) => e.name.local == 'v');
        final raw = v.isEmpty ? '' : v.first.innerText,
            type = cell.getAttribute('t');
        String text;
        if (type == 'inlineStr') {
          text = _text(cell);
        } else if (raw.isEmpty) {
          text = '';
        } else if (type == 's') {
          final index = int.tryParse(raw);
          if (index == null || index < 0 || index >= _strings.length) {
            throw const FormatException(
              'Nội dung văn bản trong file Excel không hợp lệ.',
            );
          }
          text = _strings[index];
        } else if (type == 'str') {
          text = raw;
        } else if (type == null || type == 'n') {
          final style = int.tryParse(cell.getAttribute('s') ?? '0') ?? 0;
          if (style >= 0 && style < _dateStyles.length && _dateStyles[style]) {
            throw FormatException(
              'Ô $coordinate đang ở dạng ngày/giờ. Hãy nhập văn bản hoặc số.',
            );
          }
          text = _number(raw, coordinate);
        } else {
          throw FormatException('Ô $coordinate không phải văn bản hoặc số.');
        }
        if (text.trim().isEmpty) continue;
        if (rowNumber < 1 || rowNumber > 1010 || column < 1 || column > 64) {
          throw const FormatException(
            'Sheet quá lớn. Mỗi lượt nhập tối đa 500 sản phẩm và 64 cột.',
          );
        }
        final line = values.putIfAbsent(rowNumber, () => {});
        if (line.containsKey(column)) {
          throw FormatException('Ô $coordinate bị lặp trong file Excel.');
        }
        line[column] = text;
        if (rowNumber > height) height = rowNumber;
        if (column > width) width = column;
      }
    }
    if (height == 0) {
      throw const FormatException('Sheet đã chọn chưa có dữ liệu.');
    }
    if (values.length > 510) {
      throw const FormatException('Mỗi lượt nhập tối đa 500 sản phẩm.');
    }
    final csv = List.generate(
      height,
      (r) => List.generate(
        width,
        (c) => '"${(values[r + 1]?[c + 1] ?? '').replaceAll('"', '""')}"',
      ).join(','),
    ).join('\r\n');
    if (utf8.encode(csv).length > 1024 * 1024) {
      throw const FormatException(
        'Nội dung nhập vượt quá 1 MB. Hãy chia thành các file nhỏ hơn.',
      );
    }
    return csv;
  }

  static Iterable<XmlElement> _elements(XmlNode node, String name) => node
      .descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == name);
  static String _text(XmlNode node) =>
      _elements(node, 't').map((e) => e.innerText).join();
  static XmlDocument _document(Archive archive, String name) {
    final file = archive.findFile(name);
    if (file == null) {
      throw const FormatException(
        'File Excel thiếu cấu trúc dữ liệu cần thiết.',
      );
    }
    return XmlDocument.parse(utf8.decode(file.content));
  }

  static String _number(String raw, String coordinate) {
    final match = RegExp(
          r'^(-?)(\d+)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$',
        ).firstMatch(raw),
        number = num.tryParse(raw);
    if (match == null ||
        raw.length > 80 ||
        number == null ||
        !number.isFinite ||
        number.abs() > 9007199254740991) {
      throw FormatException(
        'Số tại ô $coordinate không đọc được chính xác. Đặt mã hàng/mã vạch ở dạng Text.',
      );
    }
    final exponent = int.tryParse(match[4] ?? '0') ?? 0;
    if (exponent.abs() > 18) {
      throw FormatException('Số tại ô $coordinate vượt giới hạn nhập.');
    }
    final digits = '${match[2]}${match[3] ?? ''}',
        point = match[2]!.length + exponent;
    return '${match[1]}${point <= 0
        ? '0.${'0' * -point}$digits'
        : point >= digits.length
        ? '$digits${'0' * (point - digits.length)}'
        : '${digits.substring(0, point)}.${digits.substring(point)}'}';
  }
}
