import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

(String, String) readKnowledgeHtml(Uint8List bytes, String fileTitle) {
  if (bytes.length > 8 * 1024 * 1024) {
    throw const FormatException('Tệp quá lớn.');
  }
  final document = html.parse(bytes);
  for (final element in document.querySelectorAll(
    'script, style, nav, header, footer, aside, form, svg, noscript, [hidden]',
  )) {
    element.remove();
  }
  final body =
      document.querySelector('article') ??
      document.querySelector('main') ??
      document.body;
  for (final element
      in body?.querySelectorAll('p, h1, h2, h3, h4, li, tr, div, br') ?? []) {
    element.append(dom.Text('\n'));
  }
  final title = document.querySelector('title')?.text.trim();
  final content = (body?.text ?? '')
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
  return (title == null || title.isEmpty ? fileTitle : title, content);
}
