import 'package:edureader/features/reader/data/pdf_selection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' as pdf;

class _PageText extends pdf.PdfPageText {
  @override
  int get pageNumber => 2;

  @override
  String get fullText => 'FirstSecond';

  @override
  late final List<pdf.PdfPageTextFragment> fragments = [
    pdf.PdfPageTextFragment.fromParams(
      0,
      5,
      const pdf.PdfRect(10, 100, 35, 90),
      'First',
      [
        for (var i = 0; i < 5; i++)
          pdf.PdfRect(10 + i * 5, 100, 15 + i * 5, 90),
      ],
    ),
    pdf.PdfPageTextFragment.fromParams(
      5,
      6,
      const pdf.PdfRect(10, 80, 40, 70),
      'Second',
      [for (var i = 0; i < 6; i++) pdf.PdfRect(10 + i * 5, 80, 15 + i * 5, 70)],
    ),
  ];
}

void main() {
  test('keeps separate PDF rectangles for two selected lines', () {
    final selection = pdf.PdfTextRanges(
      pageText: _PageText(),
      ranges: [const pdf.PdfTextRange(start: 0, end: 11)],
    );

    final rects = pdfRectsForSelection(selection);
    expect(rects, hasLength(2));
    expect(rects.first.y, 100);
    expect(rects.last.y, 80);
    expect(rects.last.width, 30);
  });
}
