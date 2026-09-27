import 'dart:convert';
import 'dart:io';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../library/data/library_storage.dart';
import 'readium_storage.dart';

class NextcloudConnection {
  const NextcloudConnection({
    required this.serverUrl,
    required this.username,
    required this.appPassword,
  });

  final String serverUrl;
  final String username;
  final String appPassword;
}

class NextcloudSyncResult {
  const NextcloudSyncResult({
    required this.uploadedBooks,
    required this.downloadedBooks,
  });

  final int uploadedBooks;
  final int downloadedBooks;
}

abstract interface class NextcloudSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class FlutterNextcloudSecretStore implements NextcloudSecretStore {
  FlutterNextcloudSecretStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class NextcloudSync {
  NextcloudSync({
    http.Client? client,
    NextcloudSecretStore? secretStore,
    LibraryStorage? libraryStorage,
    ReadiumStorage? readiumStorage,
  }) : _secretStore = secretStore ?? FlutterNextcloudSecretStore(),
       _library = libraryStorage ?? LibraryStorage(),
       _readium = readiumStorage ?? ReadiumStorage(),
       _client = client ?? http.Client();

  static const _serverKey = 'nextcloud_server_url';
  static const _usernameKey = 'nextcloud_username';
  static const _passwordKey = 'nextcloud_app_password';
  static const _manifestPath = 'library-v1.json';

  final http.Client _client;
  final NextcloudSecretStore _secretStore;
  final LibraryStorage _library;
  final ReadiumStorage _readium;

  // Las operaciones leen, modifican y reescriben el índice remoto: si dos se
  // solapan (al cerrar un libro, al pasar a segundo plano o a mano), la última
  // en escribir borra lo que publicó la otra. Por eso se ejecutan en fila.
  Future<void> _queue = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<NextcloudConnection?> loadConnection() async {
    final preferences = await SharedPreferences.getInstance();
    final serverUrl = preferences.getString(_serverKey);
    final username = preferences.getString(_usernameKey);
    if (serverUrl == null || username == null) return null;
    final password = await _secretStore.read(_passwordKey);
    return NextcloudConnection(
      serverUrl: serverUrl,
      username: username,
      appPassword: password ?? '',
    );
  }

  Future<void> saveConnection({
    required String serverUrl,
    required String username,
    required String appPassword,
  }) async {
    final normalizedUrl = _normalizeServerUrl(serverUrl);
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw const FormatException('Indica el usuario de Nextcloud.');
    }
    if (appPassword.isNotEmpty) {
      await _secretStore.write(_passwordKey, appPassword);
    } else {
      final existingPassword = await _secretStore.read(_passwordKey);
      final preferences = await SharedPreferences.getInstance();
      final sameAccount =
          preferences.getString(_serverKey) == normalizedUrl &&
          preferences.getString(_usernameKey) == normalizedUsername;
      if (!sameAccount ||
          existingPassword == null ||
          existingPassword.isEmpty) {
        throw const FormatException(
          'Para cambiar de cuenta debes introducir su contraseña de aplicación.',
        );
      }
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_serverKey, normalizedUrl);
    await preferences.setString(_usernameKey, normalizedUsername);
  }

  Future<void> testConnection() => _serialized(_testConnection);

  Future<void> _testConnection() async {
    final connection = await _requireConnection();
    await _ensureCollection(connection, '');
    await _ensureCollection(connection, 'books');
    final request = http.Request('PROPFIND', _davUri(connection, ''))
      ..headers.addAll(_headers(connection))
      ..headers['Depth'] = '0';
    request.followRedirects = false;
    final response = await _client.send(request);
    if (response.statusCode != 207 && response.statusCode != 200) {
      await response.stream.drain<void>();
      throw StateError('Nextcloud respondió con HTTP ${response.statusCode}.');
    }
    await response.stream.drain<void>();
  }

  Future<NextcloudSyncResult> syncLibrary(List<EpubBook> localBooks) =>
      _serialized(() => _syncLibrary(localBooks));

  Future<NextcloudSyncResult> _syncLibrary(List<EpubBook> localBooks) async {
    final connection = await _requireConnection();
    await _ensureCollection(connection, '');
    await _ensureCollection(connection, 'books');

    final manifest = await _downloadManifest(connection);
    final localByHash = <String, EpubBook>{};
    for (final book in localBooks) {
      final path = _bookPath(book);
      if (!await File(path).exists()) continue;
      localByHash[await _sha256(path)] = book;
    }

    var uploaded = 0;
    var downloaded = 0;
    var manifestChanged = false;

    for (final entry in manifest.values.toList()) {
      var book = localByHash[entry.sha256];
      if (book == null) {
        final path = await _downloadBook(connection, entry.sha256);
        try {
          book = await _library.importBook(path);
        } finally {
          try {
            await File(path).delete();
          } on FileSystemException {
            // Temporary file cleanup is best effort after import.
          }
        }
        localByHash[entry.sha256] = book;
        downloaded++;
      }

      if (await _reconcileState(book, entry)) {
        manifest[entry.sha256] = await _entryFromLocal(book, entry.sha256);
        manifestChanged = true;
      }
    }

    for (final item in localByHash.entries) {
      if (manifest.containsKey(item.key)) continue;
      final book = item.value;
      await _uploadBook(connection, item.key, _bookPath(book));
      manifest[item.key] = await _entryFromLocal(book, item.key);
      uploaded++;
      manifestChanged = true;
    }

    if (manifestChanged) await _uploadManifest(connection, manifest);
    return NextcloudSyncResult(
      uploadedBooks: uploaded,
      downloadedBooks: downloaded,
    );
  }

  /// Sincroniza solo la posición y los marcadores de un libro. Con
  /// [uploadIfMissing] también sube el EPUB si todavía no está en Nextcloud.
  /// Si [isCancelled] devuelve true cuando llega el índice remoto, no se toca
  /// nada: sirve para descartar una sincronización que llegó tarde, cuando el
  /// lector ya está mostrando la posición local.
  Future<void> syncBook(
    EpubBook book, {
    bool uploadIfMissing = true,
    bool Function()? isCancelled,
  }) => _serialized(
    () => _syncBook(
      book,
      uploadIfMissing: uploadIfMissing,
      isCancelled: isCancelled,
    ),
  );

  Future<void> _syncBook(
    EpubBook book, {
    required bool uploadIfMissing,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() ?? false) return;
    final connection = await _requireConnection();
    final path = _bookPath(book);
    if (!await File(path).exists()) return;
    final hash = await _sha256(path);
    final manifest = await _downloadManifest(connection);
    if (isCancelled?.call() ?? false) return;
    final entry = manifest[hash];
    if (entry == null) {
      if (!uploadIfMissing) return;
      await _ensureCollection(connection, '');
      await _ensureCollection(connection, 'books');
      await _uploadBook(connection, hash, path);
    } else if (!await _reconcileState(book, entry)) {
      return;
    }
    manifest[hash] = await _entryFromLocal(book, hash);
    await _uploadManifest(connection, manifest);
  }

  /// Aplica el estado remoto si es más reciente. Devuelve true cuando el
  /// estado local es el más nuevo y hay que publicarlo en el índice.
  Future<bool> _reconcileState(EpubBook book, _NextcloudBookEntry entry) async {
    final localModifiedAt = await _readium.loadStateModifiedAt(book.id);
    if (localModifiedAt.isAfter(entry.modifiedAtDate)) return true;
    await _readium.applyRemoteState(
      bookId: book.id,
      locator: entry.locator,
      bookmarks: entry.bookmarks,
      modifiedAt: entry.modifiedAtDate,
    );
    return false;
  }

  Future<_NextcloudBookEntry> _entryFromLocal(
    EpubBook book,
    String hash,
  ) async {
    final locator = await _readium.loadLocator(book.id);
    final bookmarks = await _readium.loadBookmarks(book.id);
    final modifiedAt = await _readium.loadStateModifiedAt(book.id);
    return _NextcloudBookEntry(
      sha256: hash,
      title: book.metadata.title,
      creator: book.metadata.creator,
      modifiedAt:
          (modifiedAt.millisecondsSinceEpoch == 0
                  ? DateTime.now().toUtc()
                  : modifiedAt.toUtc())
              .toIso8601String(),
      locator: locator?.toJson(),
      bookmarks: bookmarks.map((bookmark) => bookmark.toJson()).toList(),
    );
  }

  Future<Map<String, _NextcloudBookEntry>> _downloadManifest(
    NextcloudConnection connection,
  ) async {
    final response = await _client.send(
      http.Request('GET', _davUri(connection, _manifestPath))
        ..headers.addAll(_headers(connection))
        ..followRedirects = false,
    );
    if (response.statusCode == 404) {
      await response.stream.drain<void>();
      return {};
    }
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw StateError(
        'No se pudo leer el índice de Nextcloud (HTTP ${response.statusCode}).',
      );
    }
    final json =
        jsonDecode(utf8.decode(await response.stream.toBytes()))
            as Map<String, dynamic>;
    if (json['schemaVersion'] != 1 || json['books'] is! List) {
      throw const FormatException(
        'El índice remoto de EduReader no es compatible.',
      );
    }
    final entries = <String, _NextcloudBookEntry>{};
    for (final value in json['books'] as List<dynamic>) {
      final entry = _NextcloudBookEntry.fromJson(value as Map<String, dynamic>);
      entries[entry.sha256] = entry;
    }
    return entries;
  }

  Future<void> _uploadManifest(
    NextcloudConnection connection,
    Map<String, _NextcloudBookEntry> entries,
  ) async {
    final body = jsonEncode({
      'schemaVersion': 1,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'books': entries.values.map((entry) => entry.toJson()).toList(),
    });
    final response = await _client.send(
      http.Request('PUT', _davUri(connection, _manifestPath))
        ..headers.addAll(_headers(connection))
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..body = body
        ..followRedirects = false,
    );
    await _requireStatus(response, const {200, 201, 204}, 'guardar el índice');
  }

  Future<void> _ensureCollection(
    NextcloudConnection connection,
    String path,
  ) async {
    final response = await _client.send(
      http.Request('MKCOL', _davUri(connection, path))
        ..headers.addAll(_headers(connection))
        ..followRedirects = false,
    );
    await _requireStatus(response, const {
      201,
      405,
    }, 'crear la carpeta EduReader${path.isEmpty ? '' : '/$path'}');
  }

  Future<void> _uploadBook(
    NextcloudConnection connection,
    String hash,
    String path,
  ) async {
    final file = File(path);
    final request = http.StreamedRequest(
      'PUT',
      _davUri(connection, 'books/$hash.epub'),
    )..headers.addAll(_headers(connection));
    request.followRedirects = false;
    request.contentLength = await file.length();
    final responseFuture = _client.send(request);
    await request.sink.addStream(file.openRead());
    await request.sink.close();
    final response = await responseFuture;
    await _requireStatus(response, const {200, 201, 204}, 'subir un EPUB');
  }

  Future<String> _downloadBook(
    NextcloudConnection connection,
    String hash,
  ) async {
    final response = await _client.send(
      http.Request('GET', _davUri(connection, 'books/$hash.epub'))
        ..headers.addAll(_headers(connection))
        ..followRedirects = false,
    );
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw StateError(
        'No se pudo descargar un EPUB (HTTP ${response.statusCode}).',
      );
    }
    final tempDirectory = await getTemporaryDirectory();
    final path = p.join(tempDirectory.path, 'edureader_$hash.epub');
    final sink = File(path).openWrite();
    try {
      await response.stream.pipe(sink);
    } catch (_) {
      await sink.close();
      try {
        await File(path).delete();
      } on FileSystemException {
        // Keep the original transfer error as the cause of failure.
      }
      rethrow;
    }
    if (await _sha256(path) != hash) {
      await File(path).delete();
      throw const FormatException(
        'El EPUB descargado no superó la comprobación de integridad.',
      );
    }
    return path;
  }

  Future<void> _requireStatus(
    http.StreamedResponse response,
    Set<int> accepted,
    String operation,
  ) async {
    if (!accepted.contains(response.statusCode)) {
      await response.stream.drain<void>();
      throw StateError(
        'No se pudo $operation en Nextcloud (HTTP ${response.statusCode}).',
      );
    }
    await response.stream.drain<void>();
  }

  Future<NextcloudConnection> _requireConnection() async {
    final connection = await loadConnection();
    if (connection == null || connection.appPassword.isEmpty) {
      throw StateError('Configura Nextcloud con una contraseña de aplicación.');
    }
    return connection;
  }

  Uri _davUri(NextcloudConnection connection, String path) {
    final server = _normalizeServerUrl(connection.serverUrl);
    final username = Uri.encodeComponent(connection.username);
    // Normaliza el path eliminando barras vacías y codificando cada segmento.
    final normalizedPath = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return Uri.parse(
      '$server/remote.php/dav/files/$username/EduReader${normalizedPath.isEmpty ? '' : '/$normalizedPath'}',
    );
  }

  Map<String, String> _headers(NextcloudConnection connection) => {
    'Authorization':
        'Basic ${base64Encode(utf8.encode('${connection.username}:${connection.appPassword}'))}',
    'User-Agent': 'EduReader',
  };

  String _normalizeServerUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.scheme != 'https' ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Introduce una URL segura de Nextcloud que empiece por https://.',
      );
    }
    var path = uri.path;
    while (path.endsWith('/') && path.isNotEmpty) {
      path = path.substring(0, path.length - 1);
    }
    return uri.replace(path: path).toString();
  }

  String _bookPath(EpubBook book) => book.filePath ?? book.id;

  Future<String> _sha256(String path) async =>
      (await sha256.bind(File(path).openRead()).first).toString();
}

class _NextcloudBookEntry {
  const _NextcloudBookEntry({
    required this.sha256,
    required this.title,
    required this.creator,
    required this.modifiedAt,
    required this.locator,
    required this.bookmarks,
  });

  factory _NextcloudBookEntry.fromJson(Map<String, dynamic> json) {
    final hash = json['sha256'] as String;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException(
        'El índice remoto contiene un hash EPUB no válido.',
      );
    }
    return _NextcloudBookEntry(
      sha256: hash,
      title: json['title'] as String? ?? 'EPUB',
      creator: json['creator'] as String?,
      modifiedAt: json['modifiedAt'] as String,
      locator: json['locator'] as Map<String, dynamic>?,
      bookmarks: json['bookmarks'] as List<dynamic>?,
    );
  }

  final String sha256;
  final String title;
  final String? creator;
  final String modifiedAt;
  final Map<String, dynamic>? locator;
  final List<dynamic>? bookmarks;

  DateTime get modifiedAtDate => DateTime.parse(modifiedAt);

  Map<String, dynamic> toJson() => {
    'sha256': sha256,
    'title': title,
    'creator': creator,
    'modifiedAt': modifiedAt,
    'locator': locator,
    'bookmarks': bookmarks,
  };
}
