import 'package:pdfrx/pdfrx.dart' as pdf;

import 'pdf_annotation_storage.dart';

/// Converts each selected text fragment into a PDF-page rectangle so multiline
/// highlights survive zoom and rotation synchronization.
List<PdfHighlightRect> pdfRectsForSelection(pdf.PdfPageTextRange selection) {
  final rects = <PdfHighlightRect>[];
  for (final fragment in selection.enumerateFragmentBoundingRects()) {
    final rect = fragment.bounds;
    if (rect.isEmpty) continue;
    rects.add(PdfHighlightRect(rect.left, rect.top, rect.width, rect.height));
  }
  return rects;
}
