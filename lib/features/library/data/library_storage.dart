import 'dart:convert';
import 'dart:io';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../reader/data/readium_storage.dart';

class LibraryStorage {
  LibraryStorage({
    Future<Directory> Function()? documentsDirectory,
    Future<EpubBook> Function(String)? parseBook,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _parseBook = parseBook ?? EpubParserService.parseFromFile;

  static const _pathsKey = 'library_epub_paths';
  static const _tagsPrefix = 'library_book_tags_';
  static const _statePrefixes = [
    'library_book_added_at_',
    _tagsPrefix,
    'readium_locator_',
    'readium_decorations_',
    'readium_decorations_modified_',
    'readium_bookmarks_',
    'readium_state_modified_',
    'reading_progress_',
    'freewise_last_sync_',
  ];

  final Future<Directory> Function() _documentsDirectory;
  final Future<EpubBook> Function(String) _parseBook;

  Future<List<EpubBook>> loadBooks() async {
    final preferences = await SharedPreferences.getInstance();
    final storedPaths = preferences.getStringList(_pathsKey) ?? const [];
    final documentsDirectory = await _documentsDirectory();
    final booksDirectory = Directory(p.join(documentsDirectory.path, 'books'));
    if (!await booksDirectory.exists()) return [];

    // Los contenedores de iOS pueden cambiar de ruta al actualizar la app.
    // Guardamos IDs relativos y también buscamos EPUB que versiones anteriores
    // dejaron fuera del índice al no encontrar su antigua ruta absoluta.
    final filesById = <String, File>{};
    final storedIds = <String>[];
    for (final oldId in storedPaths) {
      final id = _stableId(p.basename(oldId));
      final file = File(p.join(documentsDirectory.path, id));
      if (await file.exists() && !filesById.containsKey(id)) {
        filesById[id] = file;
        storedIds.add(id);
      }
    }
    await for (final entity in booksDirectory.list()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.epub')) {
        continue;
      }
      final id = _stableId(p.basename(entity.path));
      filesById.putIfAbsent(id, () => entity);
    }

    final books = <EpubBook>[];
    final validIds = <String>[];
    final orderedIds = [
      ...storedIds,
      ...filesById.keys.where((id) => !storedIds.contains(id)),
    ];
    for (final id in orderedIds) {
      final file = filesById[id]!;
      try {
        final book = await _parseBook(file.path);
        await _migrateLegacyState(preferences, storedPaths, id);
        final addedAt = DateTime.tryParse(
          preferences.getString(_addedAtKey(id)) ?? '',
        );
        books.add(
          book.copyWith(
            id: id,
            createdAt: addedAt ?? await file.lastModified(),
          ),
        );
        validIds.add(id);
      } catch (_) {
        // Un EPUB dañado no debe impedir que se cargue el resto de la biblioteca.
      }
    }

    if (!_sameIds(validIds, storedPaths)) {
      await preferences.setStringList(_pathsKey, validIds);
    }
    return books;
  }

  Future<EpubBook> importBook(String sourcePath) async {
    final documentsDirectory = await _documentsDirectory();
    final booksDirectory = Directory(p.join(documentsDirectory.path, 'books'));
    await booksDirectory.create(recursive: true);

    final sourceName = p.basename(sourcePath);
    final destinationName =
        '${DateTime.now().microsecondsSinceEpoch}_$sourceName';
    final destinationPath = p.join(booksDirectory.path, destinationName);
    await File(sourcePath).copy(destinationPath);

    late final EpubBook book;
    try {
      book = await _parseBook(destinationPath);
    } catch (_) {
      // No conservar copias que no se pueden abrir como EPUB.
      await File(destinationPath).delete();
      rethrow;
    }

    final preferences = await SharedPreferences.getInstance();
    final storedPaths = preferences.getStringList(_pathsKey) ?? <String>[];
    final id = _stableId(destinationName);
    if (!storedPaths.contains(id)) {
      storedPaths.add(id);
      await preferences.setStringList(_pathsKey, storedPaths);
    }
    await preferences.setString(
      _addedAtKey(id),
      DateTime.now().toUtc().toIso8601String(),
    );

    return book.copyWith(id: id);
  }

  /// Removes an EPUB and the reading state associated with its stable ID.
  Future<void> removeBook(EpubBook book) async {
    final preferences = await SharedPreferences.getInstance();
    final storedPaths = preferences.getStringList(_pathsKey) ?? <String>[];
    storedPaths.remove(book.id);
    await preferences.setStringList(_pathsKey, storedPaths);
    final path = book.filePath ?? book.id;
    final file = File(path);
    if (await file.exists()) await file.delete();

    await ReadiumStorage().removeBookState(book.id);
    await preferences.remove('reading_progress_${book.id}');
    await preferences.remove(_tagsKey(book.id));
    await preferences.remove(_addedAtKey(book.id));
  }

  Future<List<String>> loadBookTags(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_tagsKey(bookId)) ?? const [];
  }

  Future<void> saveBookTags(String bookId, List<String> tags) async {
    final preferences = await SharedPreferences.getInstance();
    final uniqueTags = <String>[];
    final seen = <String>{};
    for (final value in tags) {
      final tag = value.trim();
      if (tag.isEmpty || !seen.add(tag.toLowerCase())) continue;
      uniqueTags.add(tag);
    }
    uniqueTags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (uniqueTags.isEmpty) {
      await preferences.remove(_tagsKey(bookId));
    } else {
      await preferences.setStringList(_tagsKey(bookId), uniqueTags);
    }
  }

  String _tagsKey(String bookId) => '$_tagsPrefix$bookId';

  String _addedAtKey(String bookId) => 'library_book_added_at_$bookId';

  String _stableId(String filename) => p.join('books', filename);

  bool _sameIds(List<String> first, List<String> second) =>
      first.length == second.length &&
      Iterable.generate(
        first.length,
      ).every((index) => first[index] == second[index]);

  Future<void> _migrateLegacyState(
    SharedPreferences preferences,
    List<String> storedPaths,
    String newId,
  ) async {
    final filename = p.basename(newId);
    final oldIds = <String>{
      for (final path in storedPaths)
        if (p.isAbsolute(path) && p.basename(path) == filename) path,
    };
    for (final key in preferences.getKeys()) {
      for (final prefix in _statePrefixes) {
        if (!key.startsWith(prefix)) continue;
        final oldId = key.substring(prefix.length);
        if (p.isAbsolute(oldId) && p.basename(oldId) == filename) {
          oldIds.add(oldId);
        }
      }
    }
    for (final key in const ['epub_highlights', 'epub_notes']) {
      try {
        final records = jsonDecode(preferences.getString(key) ?? '[]') as List;
        for (final record in records) {
          if (record is! Map || record['bookId'] is! String) continue;
          final oldId = record['bookId'] as String;
          if (p.isAbsolute(oldId) && p.basename(oldId) == filename) {
            oldIds.add(oldId);
          }
        }
      } catch (_) {
        // Los registros dañados se conservan para una recuperación manual.
      }
    }
    if (oldIds.isEmpty) return;

    for (final oldId in oldIds) {
      for (final prefix in _statePrefixes) {
        final oldKey = '$prefix$oldId';
        final newKey = '$prefix$newId';
        if (!preferences.containsKey(oldKey)) continue;
        if (!preferences.containsKey(newKey)) {
          final value = preferences.get(oldKey);
          if (value is String) {
            var migrated = value;
            if (prefix == 'reading_progress_') {
              try {
                final progress = Map<String, dynamic>.from(
                  jsonDecode(value) as Map,
                );
                progress['bookId'] = newId;
                migrated = jsonEncode(progress);
              } catch (_) {
                // Se conserva el valor original si no puede interpretarse.
              }
            }
            await preferences.setString(newKey, migrated);
          } else if (value is List<String>) {
            await preferences.setStringList(newKey, value);
          }
        }
        if (preferences.containsKey(newKey)) await preferences.remove(oldKey);
      }
    }
    for (final key in const ['epub_highlights', 'epub_notes']) {
      try {
        final records = (jsonDecode(preferences.getString(key) ?? '[]') as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        var changed = false;
        for (final record in records) {
          if (oldIds.contains(record['bookId'])) {
            record['bookId'] = newId;
            changed = true;
          }
        }
        if (changed) {
          final byId = <String, Map<String, dynamic>>{};
          for (final record in records) {
            final identity = '${record['bookId']}|${record['id']}';
            final previous = byId[identity];
            if (previous == null ||
                (DateTime.tryParse(record['modifiedAt']?.toString() ?? '') ??
                        DateTime.fromMillisecondsSinceEpoch(0))
                    .isAfter(
                      DateTime.tryParse(
                            previous['modifiedAt']?.toString() ?? '',
                          ) ??
                          DateTime.fromMillisecondsSinceEpoch(0),
                    )) {
              byId[identity] = record;
            }
          }
          await preferences.setString(key, jsonEncode(byId.values.toList()));
        }
      } catch (_) {
        // No se sobrescriben anotaciones si no se pueden interpretar.
      }
    }
  }
}
