import 'dart:io';

import 'package:edureader/features/library/data/pdf_storage.dart';
import 'package:edureader/features/reader/data/pdf_reading_position.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores the page after importing the same PDF again', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('pdf-position-');
    try {
      final source = File('${directory.path}/Example.pdf');
      await source.writeAsBytes('%PDF-1.7\nexample'.codeUnits);
      final storage = PdfStorage(documentsDirectory: () async => directory);
      final first = await storage.importDocument(source.path);
      await PdfReadingPosition.save(await first.contentHash(), 8);
      await storage.removeDocument(first);
      final second = await storage.importDocument(source.path);
      expect(second.id, isNot(first.id));
      expect(
        await PdfReadingPosition.load(await second.contentHash(), second.id),
        8,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('migrates positions saved by older versions', () async {
    SharedPreferences.setMockInitialValues({'pdf_page_pdfs/old.pdf': 4});
    expect(await PdfReadingPosition.load('hash', 'pdfs/old.pdf'), 4);
    expect(await PdfReadingPosition.load('hash', 'pdfs/new.pdf'), 4);
  });
}
