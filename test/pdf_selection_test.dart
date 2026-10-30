import 'package:edureader/features/reader/data/pdf_selection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' as pdf;

/// Page 2 with "First" on one line and "Second" on the line below.
pdf.PdfPageText _pageText() {
  final first = [
    for (var i = 0; i < 5; i++) pdf.PdfRect(10 + i * 5, 100, 15 + i * 5, 90),
  ];
  final second = [
    for (var i = 0; i < 6; i++) pdf.PdfRect(10 + i * 5, 80, 15 + i * 5, 70),
  ];
  final fragments = <pdf.PdfPageTextFragment>[];
  final pageText = pdf.PdfPageText(
    pageNumber: 2,
    fullText: 'FirstSecond',
    charRects: [...first, ...second],
    fragments: fragments,
  );
  fragments.addAll([
    pdf.PdfPageTextFragment(
      pageText: pageText,
      index: 0,
      length: 5,
      bounds: const pdf.PdfRect(10, 100, 35, 90),
      charRects: first,
      direction: pdf.PdfTextDirection.ltr,
    ),
    pdf.PdfPageTextFragment(
      pageText: pageText,
      index: 5,
      length: 6,
      bounds: const pdf.PdfRect(10, 80, 40, 70),
      charRects: second,
      direction: pdf.PdfTextDirection.ltr,
    ),
  ]);
  return pageText;
}

void main() {
  test('keeps separate PDF rectangles for two selected lines', () {
    final selection = pdf.PdfPageTextRange(
      pageText: _pageText(),
      start: 0,
      end: 11,
    );

    final rects = pdfRectsForSelection(selection);
    expect(selection.pageNumber, 2);
    expect(selection.text, 'FirstSecond');
    expect(rects, hasLength(2));
    expect(rects.first.y, 100);
    expect(rects.last.y, 80);
    expect(rects.last.width, 30);
  });

  test('only covers the selected part of a line', () {
    final selection = pdf.PdfPageTextRange(
      pageText: _pageText(),
      start: 7,
      end: 10,
    );

    final rects = pdfRectsForSelection(selection);
    expect(selection.text, 'con');
    expect(rects, hasLength(1));
    expect(rects.single.y, 80);
    expect(rects.single.width, 15);
  });
}
