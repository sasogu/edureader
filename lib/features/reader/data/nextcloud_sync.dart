import 'dart:convert';
import 'dart:io';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_readium/flutter_readium.dart';
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
  static const _annotationsDirectory = 'annotations';

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

  /// Removes the book from the shared index and deletes its EPUB on Nextcloud.
  Future<void> deleteBook(EpubBook book) =>
      _serialized(() => _deleteBook(book));

  Future<void> _deleteBook(EpubBook book) async {
    final connection = await _requireConnection();
    final path = _bookPath(book);
    final hash = await _sha256(path);
    final manifest = await _downloadManifest(connection);
    final response = await _client.send(
      http.Request('DELETE', _davUri(connection, 'books/$hash.epub'))
        ..headers.addAll(_headers(connection))
        ..followRedirects = false,
    );
    await _requireStatus(response, const {
      200,
      202,
      204,
      404,
    }, 'eliminar un EPUB');
    await _deleteRemoteDecorations(connection, hash);
    manifest.books.remove(hash);
    manifest.deletedBooks[hash] = DateTime.now().toUtc();
    await _uploadManifest(connection, manifest.books, manifest.deletedBooks);
  }

  Future<NextcloudSyncResult> _syncLibrary(List<EpubBook> localBooks) async {
    final connection = await _requireConnection();
    await _ensureCollection(connection, '');
    await _ensureCollection(connection, 'books');

    final manifest = await _downloadManifest(connection);
    final localByHash = <String, EpubBook>{};
    final localBooksByHash = <String, List<EpubBook>>{};
    for (final book in localBooks) {
      final path = _bookPath(book);
      if (!await File(path).exists()) continue;
      final hash = await _sha256(path);
      final current = localByHash[hash];
      if (current == null || book.createdAt.isAfter(current.createdAt)) {
        localByHash[hash] = book;
      }
      localBooksByHash.putIfAbsent(hash, () => []).add(book);
    }

    var manifestChanged = false;
    // A deletion is shared through the manifest. Remove older local copies so
    // the next sync on this device cannot publish them again.
    for (final entry in manifest.deletedBooks.entries.toList()) {
      final localCopies = localBooksByHash[entry.key] ?? const <EpubBook>[];
      if (localCopies.any((book) => book.createdAt.isAfter(entry.value))) {
        // Re-importing the EPUB after its deletion is an intentional restore.
        manifest.deletedBooks.remove(entry.key);
        manifestChanged = true;
      } else {
        for (final staleBook in localCopies) {
          await _library.removeBook(staleBook);
        }
        localByHash.remove(entry.key);
        if (manifest.books.remove(entry.key) != null) manifestChanged = true;
      }
    }

    var uploaded = 0;
    var downloaded = 0;
    for (final entry in manifest.books.values.toList()) {
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

      final localStateIsNewer = await _reconcileState(book, entry);
      await _syncDecorations(
        connection,
        entry.sha256,
        book.id,
        remoteMayExist: true,
      );
      if (localStateIsNewer) {
        manifest.books[entry.sha256] = await _entryFromLocal(
          book,
          entry.sha256,
        );
        manifestChanged = true;
      }
    }

    for (final item in localByHash.entries) {
      if (manifest.books.containsKey(item.key)) continue;
      final book = item.value;
      await _uploadBook(connection, item.key, _bookPath(book));
      await _syncDecorations(
        connection,
        item.key,
        book.id,
        remoteMayExist: false,
      );
      manifest.books[item.key] = await _entryFromLocal(book, item.key);
      uploaded++;
      manifestChanged = true;
    }

    if (manifestChanged || manifest.deletedBooks.isNotEmpty) {
      await _uploadManifest(connection, manifest.books, manifest.deletedBooks);
    }
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
  Future<bool> syncBook(
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

  Future<bool> _syncBook(
    EpubBook book, {
    required bool uploadIfMissing,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() ?? false) return true;
    final connection = await _requireConnection();
    final path = _bookPath(book);
    if (!await File(path).exists()) return true;
    final hash = await _sha256(path);
    final manifest = await _downloadManifest(connection);
    if (isCancelled?.call() ?? false) return true;
    final deletedAt = manifest.deletedBooks[hash];
    if (deletedAt != null && !book.createdAt.isAfter(deletedAt)) return false;
    if (deletedAt != null) manifest.deletedBooks.remove(hash);
    final entry = manifest.books[hash];
    if (entry == null) {
      if (!uploadIfMissing) return true;
      await _ensureCollection(connection, '');
      await _ensureCollection(connection, 'books');
      await _uploadBook(connection, hash, path);
      await _syncDecorations(
        connection,
        hash,
        book.id,
        remoteMayExist: false,
        isCancelled: isCancelled,
      );
      if (isCancelled?.call() ?? false) return true;
    } else {
      final localStateIsNewer = await _reconcileState(book, entry);
      await _syncDecorations(
        connection,
        hash,
        book.id,
        remoteMayExist: true,
        isCancelled: isCancelled,
      );
      if (isCancelled?.call() ?? false) return true;
      if (!localStateIsNewer) return true;
    }
    manifest.books[hash] = await _entryFromLocal(book, hash);
    await _uploadManifest(connection, manifest.books, manifest.deletedBooks);
    return true;
  }

  Future<void> _syncDecorations(
    NextcloudConnection connection,
    String hash,
    String bookId, {
    required bool remoteMayExist,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() ?? false) return;
    var localDecorations = await _readium.loadDecorations(bookId);
    var localModifiedAt = await _readium.loadDecorationsModifiedAt(bookId);
    var localHasChanges = _hasLocalDecorationState(
      localDecorations,
      localModifiedAt,
    );
    if (!remoteMayExist && !localHasChanges) return;

    final response = await _client.send(
      http.Request(
        'GET',
        _davUri(connection, '$_annotationsDirectory/$hash.json'),
      )..headers.addAll(_headers(connection)),
    );
    if (isCancelled?.call() ?? false) {
      await response.stream.drain<void>();
      return;
    }
    if (response.statusCode == 404) {
      await response.stream.drain<void>();
      localDecorations = await _readium.loadDecorations(bookId);
      localModifiedAt = await _readium.loadDecorationsModifiedAt(bookId);
      localHasChanges = _hasLocalDecorationState(
        localDecorations,
        localModifiedAt,
      );
      if (localHasChanges) {
        if (localModifiedAt.millisecondsSinceEpoch == 0) {
          localModifiedAt = DateTime.now().toUtc();
          await _readium.applyRemoteDecorations(
            bookId: bookId,
            decorations: localDecorations,
            modifiedAt: localModifiedAt,
          );
        }
        await _uploadDecorations(
          connection,
          hash,
          localDecorations,
          localModifiedAt,
        );
      }
      return;
    }
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw StateError(
        'No se pudieron leer los subrayados de Nextcloud '
        '(HTTP ${response.statusCode}).',
      );
    }

    final remote =
        jsonDecode(utf8.decode(await response.stream.toBytes()))
            as Map<String, dynamic>;
    if (remote['schemaVersion'] != 1 ||
        remote['sha256'] != hash ||
        remote['decorations'] is! List) {
      throw const FormatException(
        'El archivo remoto de subrayados no es compatible.',
      );
    }
    final remoteModifiedAt = DateTime.parse(remote['updatedAt'] as String);
    final remoteDecorations = (remote['decorations'] as List<dynamic>)
        .map(
          (item) =>
              _readium.decodeDecoration(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    localDecorations = await _readium.loadDecorations(bookId);
    localModifiedAt = await _readium.loadDecorationsModifiedAt(bookId);

    if (remoteModifiedAt.isAfter(localModifiedAt)) {
      await _readium.applyRemoteDecorations(
        bookId: bookId,
        decorations: remoteDecorations,
        modifiedAt: remoteModifiedAt,
      );
    } else if (localModifiedAt.isAfter(remoteModifiedAt)) {
      await _uploadDecorations(
        connection,
        hash,
        localDecorations,
        localModifiedAt,
      );
    }
  }

  bool _hasLocalDecorationState(
    List<ReaderDecoration> decorations,
    DateTime modifiedAt,
  ) => modifiedAt.millisecondsSinceEpoch > 0 || decorations.isNotEmpty;

  Future<void> _uploadDecorations(
    NextcloudConnection connection,
    String hash,
    List<ReaderDecoration> decorations,
    DateTime modifiedAt,
  ) async {
    await _ensureCollection(connection, _annotationsDirectory);
    final body = jsonEncode({
      'schemaVersion': 1,
      'sha256': hash,
      'updatedAt': modifiedAt.toUtc().toIso8601String(),
      'decorations': decorations.map(_readium.encodeDecoration).toList(),
    });
    final response = await _client.send(
      http.Request(
          'PUT',
          _davUri(connection, '$_annotationsDirectory/$hash.json'),
        )
        ..headers.addAll(_headers(connection))
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..body = body
        ..followRedirects = false,
    );
    await _requireStatus(response, const {200, 201, 204}, 'guardar subrayados');
  }

  Future<void> _deleteRemoteDecorations(
    NextcloudConnection connection,
    String hash,
  ) async {
    final response = await _client.send(
      http.Request(
          'DELETE',
          _davUri(connection, '$_annotationsDirectory/$hash.json'),
        )
        ..headers.addAll(_headers(connection))
        ..followRedirects = false,
    );
    await _requireStatus(response, const {
      200,
      202,
      204,
      404,
    }, 'eliminar subrayados');
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

  Future<_NextcloudManifest> _downloadManifest(
    NextcloudConnection connection,
  ) async {
    final response = await _client.send(
      http.Request('GET', _davUri(connection, _manifestPath))
        ..headers.addAll(_headers(connection))
        ..followRedirects = false,
    );
    if (response.statusCode == 404) {
      await response.stream.drain<void>();
      return _NextcloudManifest();
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
    if (!{1, 2}.contains(json['schemaVersion']) || json['books'] is! List) {
      throw const FormatException(
        'El índice remoto de EduReader no es compatible.',
      );
    }
    final entries = <String, _NextcloudBookEntry>{};
    for (final value in json['books'] as List<dynamic>) {
      final entry = _NextcloudBookEntry.fromJson(value as Map<String, dynamic>);
      entries[entry.sha256] = entry;
    }
    final deletedBooks = <String, DateTime>{};
    final deletedJson = json['deletedBooks'];
    if (deletedJson is Map<String, dynamic>) {
      for (final item in deletedJson.entries) {
        if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(item.key)) continue;
        final deletedAt = item.value is String
            ? DateTime.tryParse(item.value as String)
            : null;
        if (deletedAt != null) deletedBooks[item.key] = deletedAt.toUtc();
      }
    }
    return _NextcloudManifest(books: entries, deletedBooks: deletedBooks);
  }

  Future<void> _uploadManifest(
    NextcloudConnection connection,
    Map<String, _NextcloudBookEntry> entries, [
    Map<String, DateTime> deletedBooks = const {},
  ]) async {
    final body = jsonEncode({
      'schemaVersion': deletedBooks.isEmpty ? 1 : 2,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'books': entries.values.map((entry) => entry.toJson()).toList(),
      if (deletedBooks.isNotEmpty)
        'deletedBooks': {
          for (final entry in deletedBooks.entries)
            entry.key: entry.value.toUtc().toIso8601String(),
        },
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

class _NextcloudManifest {
  _NextcloudManifest({
    Map<String, _NextcloudBookEntry>? books,
    Map<String, DateTime>? deletedBooks,
  }) : books = books ?? {},
       deletedBooks = deletedBooks ?? {};

  final Map<String, _NextcloudBookEntry> books;
  final Map<String, DateTime> deletedBooks;
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
