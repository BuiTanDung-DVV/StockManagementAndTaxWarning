import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:archive/archive.dart';

/// A small, typed OOXML writer for application exports. Literal text is never
/// interpreted as a formula, and no images, macros or external links are added.
class XlsxCell {
  final String value;
  final int style;
  final bool text;
  final String? formula;
  const XlsxCell.text(this.value, {this.style = 0})
    : text = true,
      formula = null;
  const XlsxCell.number(this.value, {this.style = 4})
    : text = false,
      formula = null;
  const XlsxCell.formula(this.formula, this.value, {this.style = 7})
    : text = false;
  factory XlsxCell.date(String value, {int style = 11}) {
    final date = DateTime.parse('${value}T00:00:00Z');
    return XlsxCell.number(
      '${date.difference(DateTime.utc(1899, 12, 30)).inDays}',
      style: style,
    );
  }
  factory XlsxCell.timestamp(DateTime value) {
    final vn = value.toUtc().add(const Duration(hours: 7));
    final serial =
        DateTime.utc(
          vn.year,
          vn.month,
          vn.day,
          vn.hour,
          vn.minute,
          vn.second,
        ).difference(DateTime.utc(1899, 12, 30)).inMilliseconds /
        86400000;
    return XlsxCell.number('$serial', style: 9);
  }
}

class ReportXlsxWriter {
  static String column(int index) {
    var value = index + 1, result = '';
    while (value > 0) {
      value--;
      result = String.fromCharCode(65 + value % 26) + result;
      value ~/= 26;
    }
    return result;
  }

  static String _xml(String text) {
    if (text.length > 32767 ||
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]').hasMatch(text)) {
      throw const FormatException('Văn bản không hợp lệ để xuất Excel');
    }
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static Uint8List build({
    required String sheetName,
    required List<double> widths,
    required Map<int, List<XlsxCell?>> rows,
    required List<String> merges,
    required int dataCount,
    Map<int, double> heights = const {},
    int headerRow = 8,
    int printWidth = 1,
    int printTitleStartRow = 1,
    List<String>? printAreas,
    String? printHeader,
  }) {
    if (widths.isEmpty ||
        widths.length > 16384 ||
        rows.isEmpty ||
        sheetName.length > 31) {
      throw const FormatException('Cấu trúc Excel không hợp lệ');
    }
    final lastRow = rows.keys.reduce(math.max),
        lastColumn = column(widths.length - 1);
    if (lastRow > 1048576) {
      throw const FormatException('Số dòng vượt giới hạn Excel');
    }
    final dataEnd = headerRow + dataCount;
    final areas = printAreas ?? ['A1:$lastColumn$lastRow'];
    if (areas.isEmpty ||
        areas.any(
          (area) => !RegExp(r'^[A-Z]+[1-9]\d*:[A-Z]+[1-9]\d*$').hasMatch(area),
        ) ||
        printTitleStartRow < 1 ||
        printTitleStartRow > headerRow ||
        (printHeader?.length ?? 0) > 240) {
      throw const FormatException('Vùng in Excel không hợp lệ');
    }
    final rowXml = StringBuffer();
    final numbers = RegExp(r'^-?\d+(?:\.\d+)?$');
    for (final index in rows.keys.toList()..sort()) {
      final values = rows[index]!;
      if (values.length > widths.length) {
        throw const FormatException('Số cột dữ liệu Excel không khớp');
      }
      var height = 24.0;
      final cells = StringBuffer();
      for (var col = 0; col < values.length; col++) {
        final cell = values[col];
        if (cell == null) continue;
        final ref = '${column(col)}$index';
        if (cell.text) {
          if (index > headerRow) {
            final lines = cell.value
                .split('\n')
                .fold<int>(
                  0,
                  (sum, line) =>
                      sum +
                      math.max(
                        1,
                        (line.length / math.max(3, widths[col] - 2)).ceil(),
                      ),
                );
            height = math.max(height, math.min(409, lines * 15.0 + 8));
          }
          cells.write(
            '<c r="$ref" s="${cell.style}" t="inlineStr"><is><t xml:space="preserve">${_xml(cell.value)}</t></is></c>',
          );
        } else {
          if (!numbers.hasMatch(cell.value) ||
              !double.parse(cell.value).isFinite) {
            throw const FormatException('Số liệu Excel không hợp lệ');
          }
          if (const {6, 7, 15}.contains(cell.style)) {
            final parts = cell.value.replaceFirst('-', '').split('.');
            final fraction = parts.length == 1 ? '' : parts[1];
            final cents = '${parts[0]}${fraction.padRight(2, '0')}'
                .replaceFirst(RegExp(r'^0+'), '');
            if (fraction.length > 2 || cents.length > 15) {
              throw const FormatException(
                'Số tiền vượt độ chính xác của Excel. Hãy thu hẹp bộ lọc xuất.',
              );
            }
          }
          cells.write(
            '<c r="$ref" s="${cell.style}">${cell.formula == null ? '' : '<f>${_xml(cell.formula!)}</f>'}<v>${cell.value}</v></c>',
          );
        }
      }
      rowXml.write(
        '<row r="$index" ht="${heights[index] ?? height}" customHeight="1">$cells</row>',
      );
    }
    final archive = Archive();
    void part(String name, String value) {
      final bytes = utf8.encode(value);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    part(
      '[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>',
    );
    part(
      '_rels/.rels',
      '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    );
    final quoted = _xml("'${sheetName.replaceAll("'", "''")}'");
    final printArea = areas
        .map((area) {
          final absolute = area.replaceAllMapped(
            RegExp(r'([A-Z]+)(\d+)'),
            (match) => '\$${match[1]}\$${match[2]}',
          );
          return '$quoted!$absolute';
        })
        .join(',');
    part(
      'xl/workbook.xml',
      '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><bookViews><workbookView/></bookViews><sheets><sheet name="${_xml(sheetName)}" sheetId="1" r:id="rId1"/></sheets><definedNames><definedName name="_xlnm.Print_Titles" localSheetId="0">$quoted!\$$printTitleStartRow:\$$headerRow,$quoted!\$A:\$B</definedName><definedName name="_xlnm.Print_Area" localSheetId="0">$printArea</definedName></definedNames><calcPr calcId="191029" calcMode="auto" fullCalcOnLoad="1"/></workbook>',
    );
    part(
      'xl/_rels/workbook.xml.rels',
      '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
    );
    part('xl/styles.xml', _styles());
    part(
      'xl/worksheets/sheet1.xml',
      '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetPr><pageSetUpPr fitToPage="1"/></sheetPr><dimension ref="A1:$lastColumn$lastRow"/><sheetViews><sheetView workbookViewId="0" showGridLines="0"><pane xSplit="2" ySplit="$headerRow" topLeftCell="C${headerRow + 1}" activePane="bottomRight" state="frozen"/><selection pane="bottomRight" activeCell="C${headerRow + 1}" sqref="C${headerRow + 1}"/></sheetView></sheetViews><sheetFormatPr defaultRowHeight="24"/><cols>${[for (var i = 0; i < widths.length; i++) '<col min="${i + 1}" max="${i + 1}" width="${widths[i]}" customWidth="1"/>'].join()}</cols><sheetData>$rowXml</sheetData><autoFilter ref="A$headerRow:$lastColumn$dataEnd"/><mergeCells count="${merges.length}">${merges.map((ref) => '<mergeCell ref="$ref"/>').join()}</mergeCells><printOptions horizontalCentered="1"/><pageMargins left="0.3" right="0.3" top="0.5" bottom="0.4" header="0.2" footer="0.2"/><pageSetup paperSize="9" orientation="landscape" fitToWidth="$printWidth" fitToHeight="0"/><headerFooter>${printHeader == null ? '' : '<oddHeader>&amp;L&amp;9${_xml(printHeader.replaceAll('&', '&&'))}</oddHeader>'}<oddFooter>&amp;L${_xml(sheetName)}&amp;RTrang &amp;P / &amp;N</oddFooter></headerFooter></worksheet>',
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _styles() {
    String font(String color, {bool bold = false, double size = 11}) =>
        '<font><sz val="$size"/><color rgb="FF$color"/><name val="Calibri"/>${bold ? '<b/>' : ''}</font>';
    String xf(
      int font,
      int fill,
      int border,
      int format, {
      String align = 'left',
      bool wrap = true,
    }) =>
        '<xf numFmtId="$format" fontId="$font" fillId="$fill" borderId="$border" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="$align" vertical="top" wrapText="${wrap ? 1 : 0}"/></xf>';
    return '<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="4"><numFmt numFmtId="164" formatCode="#,##0"/><numFmt numFmtId="165" formatCode="dd/mm/yyyy"/><numFmt numFmtId="166" formatCode="#,##0.00 &quot;đ&quot;"/><numFmt numFmtId="167" formatCode="dd/mm/yyyy hh:mm"/></numFmts><fonts count="5">${font('172B35')}${font('172B35', bold: true, size: 17)}${font('536875', size: 10)}${font('FFFFFF', bold: true)}${font('172B35', bold: true)}</fonts><fills count="5"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF0F766E"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE8F4F2"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFF3F6F8"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left/><right/><top/><bottom style="thin"><color rgb="FFE0E6EB"/></bottom><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="16">${xf(0, 0, 1, 0)}${xf(1, 0, 0, 0)}${xf(2, 0, 0, 0)}${xf(3, 2, 1, 0)}${xf(0, 0, 1, 164, align: 'right')}${xf(0, 0, 1, 165, align: 'center')}${xf(0, 0, 1, 166, align: 'right')}${xf(4, 3, 0, 166, align: 'right')}${xf(2, 0, 0, 0)}${xf(2, 0, 0, 167)}${xf(4, 0, 0, 164, align: 'right')}${xf(0, 0, 0, 165)}${xf(0, 4, 1, 0)}${xf(0, 4, 1, 164, align: 'right')}${xf(0, 4, 1, 165, align: 'center')}${xf(0, 4, 1, 166, align: 'right')}</cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>';
  }
}
