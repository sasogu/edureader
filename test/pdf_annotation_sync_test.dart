import 'dart:io';

import 'package:edureader/features/library/data/pdf_storage.dart';
import 'package:edureader/features/reader/data/nextcloud_sync.dart';
import 'package:edureader/features/reader/data/pdf_annotation_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Secrets implements NextcloudSecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('newer PDF note and deletion win during merge', () async {
    final storage = PdfAnnotationStorage();
    final old = PdfAnnotation(
      id: 'mark-1',
      pageIndex: 2,
      text: 'Selected text',
      rects: [const PdfHighlightRect(10, 40, 20, 8)],
      color: 0xfffff176,
      note: 'old',
      modifiedAt: DateTime.utc(2026, 1),
    );
    await storage.merge('pdfs/a.pdf', [old]);
    await storage.merge('pdfs/a.pdf', [
      old.copyWith(note: 'new', modifiedAt: DateTime.utc(2026, 2)),
    ]);
    await storage.merge('pdfs/a.pdf', [old]);
    expect((await storage.load('pdfs/a.pdf')).single.note, 'new');

    await storage.merge('pdfs/a.pdf', [
      old.copyWith(deleted: true, modifiedAt: DateTime.utc(2026, 3)),
    ]);
    expect((await storage.load('pdfs/a.pdf')).single.deleted, isTrue);
  });

  test('restores annotations on another copy of the same PDF', () async {
    final directory = await Directory.systemTemp.createTemp(
      'edureader-pdf-sync-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/book.pdf');
    await file.writeAsBytes('%PDF-1.7\n'.codeUnits);
    final first = PdfDocument(
      id: 'pdfs/first.pdf',
      path: file.path,
      title: 'book',
    );
    final second = PdfDocument(
      id: 'pdfs/second.pdf',
      path: file.path,
      title: 'book',
    );
    final annotation = PdfAnnotation(
      id: 'mark-2',
      pageIndex: 0,
      text: 'A passage',
      rects: [const PdfHighlightRect(2, 30, 15, 5)],
      color: 0xfffff176,
      note: 'My note',
      modifiedAt: DateTime.utc(2026, 4),
    );
    final hash = await first.contentHash();
    await PdfAnnotationStorage().merge(hash, [annotation]);

    String? remoteBody;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return remoteBody == null
            ? http.Response('', 404)
            : http.Response(remoteBody!, 200);
      }
      if (request.method == 'PUT') {
        remoteBody = request.body;
        return http.Response('', 201);
      }
      return http.Response('', 201);
    });
    final secrets = _Secrets();
    final sync = NextcloudSync(client: client, secretStore: secrets);
    await sync.saveConnection(
      serverUrl: 'https://cloud.example.org',
      username: 'reader',
      appPassword: 'test-password',
    );
    await sync.syncPdfAnnotations(first);
    SharedPreferences.setMockInitialValues(
      {},
    ); // A second device with the same PDF.
    final secondSync = NextcloudSync(client: client, secretStore: secrets);
    await secondSync.saveConnection(
      serverUrl: 'https://cloud.example.org',
      username: 'reader',
      appPassword: 'test-password',
    );
    await secondSync.syncPdfAnnotations(second);

    final restored = (await PdfAnnotationStorage().load(hash)).single;
    expect(restored.text, 'A passage');
    expect(restored.note, 'My note');
    expect(restored.rects.single.width, 15);

    await PdfAnnotationStorage().delete(hash, restored);
    await secondSync.syncPdfAnnotations(second);
    SharedPreferences.setMockInitialValues({});
    final thirdSync = NextcloudSync(client: client, secretStore: secrets);
    await thirdSync.saveConnection(
      serverUrl: 'https://cloud.example.org',
      username: 'reader',
      appPassword: 'test-password',
    );
    await thirdSync.syncPdfAnnotations(first);
    expect((await PdfAnnotationStorage().load(hash)).single.deleted, isTrue);
  });
}
