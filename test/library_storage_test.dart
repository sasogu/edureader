import 'dart:convert';
import 'dart:io';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:edureader/features/library/data/library_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late LibraryStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    documents = await Directory.systemTemp.createTemp('edureader-library-');
    storage = LibraryStorage(
      documentsDirectory: () async => documents,
      parseBook: (path) async => EpubBook(
        id: path,
        metadata: EpubMetadata(title: 'Libro de prueba'),
        chapters: [],
        spine: [],
        manifest: {},
        tableOfContents: [],
        navigation: [],
        filePath: path,
        createdAt: DateTime.utc(2026),
      ),
    );
  });

  tearDown(() => documents.delete(recursive: true));

  test('recovers a moved iOS book and all path-keyed reading state', () async {
    const filename = '123_reader.epub';
    const oldId = '/old-container/Documents/books/$filename';
    const newId = 'books/$filename';
    final booksDirectory = Directory('${documents.path}/books');
    await booksDirectory.create();
    final currentFile = File('${booksDirectory.path}/$filename');
    await currentFile.writeAsString('book');
    SharedPreferences.setMockInitialValues({
      'library_epub_paths': [oldId],
      'library_book_added_at_$oldId': '2026-01-02T00:00:00.000Z',
      'library_book_tags_$oldId': ['Ensayo'],
      'readium_locator_$oldId': '{"href":"chapter.xhtml"}',
      'readium_decorations_$oldId': '[]',
      'readium_bookmarks_$oldId': '[]',
      'reading_progress_$oldId': jsonEncode({'bookId': oldId, 'chapter': 1}),
      'freewise_last_sync_$oldId': '2026-01-03T00:00:00.000Z',
      'epub_highlights': jsonEncode([
        {'id': 'h1', 'bookId': oldId, 'text': 'Fragmento'},
      ]),
      'epub_notes': jsonEncode([
        {'id': 'n1', 'bookId': oldId, 'content': 'Nota'},
      ]),
    });

    final books = await storage.loadBooks();
    final preferences = await SharedPreferences.getInstance();

    expect(books.single.id, newId);
    expect(books.single.filePath, currentFile.path);
    expect(books.single.createdAt, DateTime.utc(2026, 1, 2));
    expect(preferences.getStringList('library_epub_paths'), [newId]);
    expect(preferences.getStringList('library_book_tags_$newId'), ['Ensayo']);
    expect(preferences.getString('readium_locator_$newId'), isNotNull);
    expect(preferences.getString('readium_decorations_$newId'), '[]');
    expect(preferences.getString('readium_bookmarks_$newId'), '[]');
    expect(
      jsonDecode(preferences.getString('reading_progress_$newId')!)['bookId'],
      newId,
    );
    expect(preferences.getString('freewise_last_sync_$newId'), isNotNull);
    expect(
      jsonDecode(preferences.getString('epub_highlights')!)[0]['bookId'],
      newId,
    );
    expect(
      jsonDecode(preferences.getString('epub_notes')!)[0]['bookId'],
      newId,
    );
    expect(preferences.containsKey('readium_locator_$oldId'), isFalse);
  });

  test(
    'finds a book omitted from the old index after a container change',
    () async {
      const filename = '456_reader.epub';
      const oldId = '/old-container/Documents/books/$filename';
      const newId = 'books/$filename';
      final booksDirectory = Directory('${documents.path}/books');
      await booksDirectory.create();
      await File('${booksDirectory.path}/$filename').writeAsString('book');
      SharedPreferences.setMockInitialValues({
        'library_epub_paths': <String>[],
        'readium_decorations_$oldId': '[]',
        'epub_notes': jsonEncode([
          {'id': 'n1', 'bookId': oldId, 'content': 'Nota'},
        ]),
      });

      final books = await storage.loadBooks();
      final preferences = await SharedPreferences.getInstance();

      expect(books.single.id, newId);
      expect(preferences.getStringList('library_epub_paths'), [newId]);
      expect(preferences.getString('readium_decorations_$newId'), '[]');
      expect(
        jsonDecode(preferences.getString('epub_notes')!)[0]['bookId'],
        newId,
      );
    },
  );

  test(
    'uses a stable ID for new imports and removes the private copy',
    () async {
      final source = File('${documents.path}/source.epub');
      await source.writeAsString('book');

      final book = await storage.importBook(source.path);
      expect(book.id, startsWith('books/'));
      expect(File(book.filePath!).existsSync(), isTrue);

      await storage.removeBook(book);
      expect(File(book.filePath!).existsSync(), isFalse);
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'library_epub_paths',
        ),
        isEmpty,
      );
    },
  );
}
