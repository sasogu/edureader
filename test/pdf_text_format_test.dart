import 'package:edureader/features/reader/data/pdf_text_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('joins wrapped lines and preserves paragraphs', () {
    expect(
      reflowPdfText('Un texto\npartido en dos líneas.\n\nOtro párrafo.'),
      'Un texto partido en dos líneas.\n\nOtro párrafo.',
    );
  });

  test('joins a word split by a PDF line break', () {
    expect(reflowPdfText('Lec-\ntura cómoda.'), 'Lectura cómoda.');
  });
}
