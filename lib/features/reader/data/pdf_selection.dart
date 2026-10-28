import 'package:pdfrx/pdfrx.dart' as pdf;

import 'pdf_annotation_storage.dart';

/// Converts each selected line into a PDF-page rectangle so multiline
/// highlights survive zoom, rotation and synchronization.
List<PdfHighlightRect> pdfRectsForSelection(pdf.PdfTextRanges selection) {
  final rects = <PdfHighlightRect>[];
  for (final range in selection.ranges) {
    final shaped = range.toTextRangeWithFragments(selection.pageText);
    if (shaped == null) continue;
    for (final rect in shaped.enumerateRectsForRange()) {
      if (rect.isEmpty) continue;
      rects.add(PdfHighlightRect(rect.left, rect.top, rect.width, rect.height));
    }
  }
  return rects;
}
