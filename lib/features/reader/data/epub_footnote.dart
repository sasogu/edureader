import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// Turns the note fragment supplied by Readium into readable dialog text.
/// Backlinks to the reading position are unnecessary because the dialog does
/// not move the reader.
String epubFootnoteText(String content) {
  final fragment = html.parseFragment(content);
  final buffer = StringBuffer();

  void visit(Node node) {
    if (node is Text) {
      buffer.write(node.text);
      return;
    }
    if (node is! Element) {
      for (final child in node.nodes) {
        visit(child);
      }
      return;
    }
    final tag = node.localName;
    if (tag == 'script' || tag == 'style') return;
    final role =
        '${node.attributes['epub:type'] ?? ''} ${node.attributes['role'] ?? ''}';
    if (tag == 'a' &&
        (role.contains('backlink') || role.contains('doc-backlink'))) {
      return;
    }
    if (tag == 'br') {
      buffer.write('\n');
      return;
    }
    for (final child in node.nodes) {
      visit(child);
    }
    if (const {
      'p',
      'div',
      'aside',
      'li',
      'section',
      'blockquote',
    }.contains(tag)) {
      buffer.write('\n');
    }
  }

  visit(fragment);
  return buffer
      .toString()
      .replaceAll(RegExp(r'[ \t\r\f]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
