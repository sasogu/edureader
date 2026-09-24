import 'dart:convert';
import 'dart:io';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:edureader/features/reader/data/nextcloud_sync.dart';
import 'package:edureader/features/reader/data/readium_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecretStore implements NextcloudSecretStore {
  final Map<String, String> values = {};

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

  test('stores the app password outside shared preferences', () async {
    final secrets = _MemorySecretStore();
    final sync = NextcloudSync(
      client: MockClient((_) async => http.Response('', 201)),
      secretStore: secrets,
    );

    await sync.saveConnection(
      serverUrl: 'https://cloud.example.org/nextcloud/',
      username: 'reader',
      appPassword: 'application-secret',
    );

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('nextcloud_server_url'),
      'https://cloud.example.org/nextcloud',
    );
    expect(preferences.getString('nextcloud_username'), 'reader');
    expect(preferences.getKeys(), isNot(contains('nextcloud_app_password')));
    expect(secrets.values['nextcloud_app_password'], 'application-secret');
  });

  test(
    'tests the Nextcloud WebDAV connection with HTTPS and Basic auth',
    () async {
      final secrets = _MemorySecretStore();
      final methods = <String>[];
      final client = MockClient((request) async {
        methods.add(request.method);
        expect(request.url.scheme, 'https');
        expect(
          request.headers['authorization'],
          'Basic ${base64Encode(utf8.encode('reader:secret'))}',
        );
        if (request.method == 'PROPFIND') {
          expect(request.headers['depth'], '0');
          expect(
            request.url.path,
            endsWith('/remote.php/dav/files/reader/EduReader'),
          );
          return http.Response('', 207);
        }
        return http.Response('', 201);
      });
      final sync = NextcloudSync(client: client, secretStore: secrets);
      await sync.saveConnection(
        serverUrl: 'https://cloud.example.org',
        username: 'reader',
        appPassword: 'secret',
      );

      await sync.testConnection();

      expect(methods, ['MKCOL', 'MKCOL', 'PROPFIND']);
    },
  );

  test('rejects insecure Nextcloud URLs', () async {
    final sync = NextcloudSync(secretStore: _MemorySecretStore());

    await expectLater(
      sync.saveConnection(
        serverUrl: 'http://cloud.example.org',
        username: 'reader',
        appPassword: 'secret',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'uploads each local EPUB once and publishes its hash in the manifest',
    () async {
      final secrets = _MemorySecretStore();
      final directory = await Directory.systemTemp.createTemp(
        'edureader-sync-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final epub = File('${directory.path}/book.epub');
      final bytes = utf8.encode('epub-test-content');
      await epub.writeAsBytes(bytes);
      final hash = sha256.convert(bytes).toString();
      Map<String, dynamic>? uploadedManifest;
      var epubUploads = 0;
      final client = MockClient((request) async {
        if (request.method == 'MKCOL') return http.Response('', 201);
        if (request.method == 'GET') return http.Response('', 404);
        if (request.method == 'PUT' && request.url.path.endsWith('.epub')) {
          epubUploads++;
          expect(request.bodyBytes, bytes);
          return http.Response('', 201);
        }
        if (request.method == 'PUT' &&
            request.url.path.endsWith('library-v1.json')) {
          uploadedManifest = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('', 201);
        }
        return http.Response('', 405);
      });
      final sync = NextcloudSync(client: client, secretStore: secrets);
      await sync.saveConnection(
        serverUrl: 'https://cloud.example.org',
        username: 'reader',
        appPassword: 'secret',
      );
      final book = EpubBook(
        id: 'local-book',
        metadata: EpubMetadata(title: 'Libro', creator: 'Autora'),
        chapters: [],
        spine: [],
        manifest: {},
        tableOfContents: [],
        navigation: [],
        filePath: '',
        createdAt: DateTime.utc(2026),
      );
      final result = await sync.syncLibrary([
        book.copyWith(filePath: epub.path),
      ]);

      expect(result.uploadedBooks, 1);
      expect(result.downloadedBooks, 0);
      expect(epubUploads, 1);
      final remoteBook = (uploadedManifest!['books'] as List).single;
      expect(remoteBook['sha256'], hash);
      expect(remoteBook['title'], 'Libro');
    },
  );

  test('restores synced bookmark state and its conflict timestamp', () async {
    final storage = ReadiumStorage();
    final modifiedAt = DateTime.utc(2026, 9, 24, 18);

    await storage.applyRemoteState(
      bookId: 'local-book',
      locator: null,
      bookmarks: const [],
      modifiedAt: modifiedAt,
    );

    expect(await storage.loadBookmarks('local-book'), isEmpty);
    expect(await storage.loadStateModifiedAt('local-book'), modifiedAt);
  });
}
