import 'dart:io';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../reader/data/readium_storage.dart';

class LibraryStorage {
  static const _pathsKey = 'library_epub_paths';
  static const _tagsPrefix = 'library_book_tags_';

  Future<List<EpubBook>> loadBooks() async {
    final preferences = await SharedPreferences.getInstance();
    final storedPaths = preferences.getStringList(_pathsKey) ?? const [];
    final books = <EpubBook>[];
    final validPaths = <String>[];

    for (final path in storedPaths) {
      try {
        if (!await File(path).exists()) continue;
        final book = await EpubParserService.parseFromFile(path);
        books.add(book.copyWith(id: path));
        validPaths.add(path);
      } catch (_) {
        // Un EPUB dañado no debe impedir que se cargue el resto de la biblioteca.
      }
    }

    if (validPaths.length != storedPaths.length) {
      await preferences.setStringList(_pathsKey, validPaths);
    }
    return books;
  }

  Future<EpubBook> importBook(String sourcePath) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final booksDirectory = Directory(p.join(documentsDirectory.path, 'books'));
    await booksDirectory.create(recursive: true);

    final sourceName = p.basename(sourcePath);
    final destinationName =
        '${DateTime.now().microsecondsSinceEpoch}_$sourceName';
    final destinationPath = p.join(booksDirectory.path, destinationName);
    await File(sourcePath).copy(destinationPath);

    late final EpubBook book;
    try {
      book = await EpubParserService.parseFromFile(destinationPath);
    } catch (_) {
      // No conservar copias que no se pueden abrir como EPUB.
      await File(destinationPath).delete();
      rethrow;
    }

    final preferences = await SharedPreferences.getInstance();
    final storedPaths = preferences.getStringList(_pathsKey) ?? <String>[];
    if (!storedPaths.contains(destinationPath)) {
      storedPaths.add(destinationPath);
      await preferences.setStringList(_pathsKey, storedPaths);
    }

    return book.copyWith(id: destinationPath);
  }

  /// Removes an EPUB and the reading state associated with its local path.
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
}
