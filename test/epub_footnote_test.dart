import 'package:edureader/features/reader/data/epub_footnote.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps numbered note text and removes the return link', () {
    const html =
        '<aside epub:type="footnote"><p>12. Una <em>nota</em> '
        'con detalle.</p><p>Segunda línea. '
        '<a epub:type="backlink" href="chapter.xhtml#ref12">↩</a></p></aside>';

    expect(epubFootnoteText(html), '12. Una nota con detalle.\nSegunda línea.');
  });

  test('handles line breaks and escaped characters', () {
    expect(
      epubFootnoteText('<div>1. A &amp; B<br>Otro dato</div>'),
      '1. A & B\nOtro dato',
    );
  });
}
