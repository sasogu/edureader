import 'dart:io';

import 'package:edureader/features/library/data/pdf_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PdfStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('edureader-pdf-test-');
    storage = PdfStorage(documentsDirectory: () async => directory);
  });

  tearDown(() async => directory.delete(recursive: true));

  test('imports, reloads and removes a PDF', () async {
    final source = File('${directory.path}/Example.pdf');
    await source.writeAsBytes('%PDF-1.7\n'.codeUnits);

    final document = await storage.importDocument(source.path);
    expect(document.title, 'Example');
    expect((await storage.loadDocuments()).single.id, document.id);

    await storage.removeDocument(document);
    expect(await storage.loadDocuments(), isEmpty);
  });

  test('rejects a file with a PDF extension but no PDF header', () async {
    final source = File('${directory.path}/bad.pdf');
    await source.writeAsString('not a PDF');

    await expectLater(
      storage.importDocument(source.path),
      throwsFormatException,
    );
    expect(await storage.loadDocuments(), isEmpty);
  });
}
