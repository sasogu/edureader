import 'dart:io';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LibraryStorage {
  static const _pathsKey = 'library_epub_paths';

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

    final preferences = await SharedPreferences.getInstance();
    final storedPaths = preferences.getStringList(_pathsKey) ?? <String>[];
    if (!storedPaths.contains(destinationPath)) {
      storedPaths.add(destinationPath);
      await preferences.setStringList(_pathsKey, storedPaths);
    }

    final book = await EpubParserService.parseFromFile(destinationPath);
    return book.copyWith(id: destinationPath);
  }
}
