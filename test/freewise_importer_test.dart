import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:csv/csv.dart';
import 'package:edureader/features/reader/data/annotation_storage.dart';
import 'package:edureader/features/reader/data/freewise_importer.dart';
import 'package:edureader/features/reader/data/readium_storage.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final book = EpubBook(
    id: 'books/test.epub',
    metadata: EpubMetadata(title: 'Mi libro', creator: 'Autora'),
    chapters: [],
    spine: [],
    manifest: {},
    tableOfContents: [],
    navigation: [],
    filePath: '/documents/books/test.epub',
    createdAt: DateTime.utc(2026),
  );
  final csv = const ListToCsvConverter().convert([
    [
      'Highlight',
      'Book Title',
      'Book Author',
      'Note',
      'Location Type',
      'Location',
      'Highlighted at',
    ],
    [
      'Un texto, importante',
      'Mi libro',
      'Autora',
      'Mi nota',
      'order',
      '0',
      '2026-09-01T12:00:00Z',
    ],
    ['Otro texto', 'Otro libro', 'Autora', '', 'order', '0', ''],
  ]);
  final locator = Locator.fromJson({
    'href': 'chapter.xhtml',
    'type': 'application/xhtml+xml',
    'text': {'highlight': 'Un texto, importante'},
    'locations': {'progression': 0.25},
  })!;

  test(
    'imports only this book, restores visual marks and avoids duplicates',
    () async {
      final importer = FreeWiseImporter();
      final entries = importer.parseForBook(book, csv);
      expect(entries, hasLength(1));
      var applyCalls = 0;
      Future<void> apply(List<ReaderDecoration> decorations) async {
        applyCalls++;
        expect(decorations, hasLength(1));
      }

      final first = await importer.importEntries(
        book,
        entries,
        search: (_) async => [TextSearchResult(locator: locator)],
        applyDecorations: apply,
      );
      expect(first.highlights, 1);
      expect(first.notes, 1);
      expect(first.visualHighlights, 1);
      expect(first.unlocated, 0);
      expect(
        (await AnnotationStorage().loadNotes(book.id)).single.content,
        'Mi nota',
      );
      expect(await ReadiumStorage().loadDecorations(book.id), hasLength(1));

      final second = await importer.importEntries(
        book,
        entries,
        search: (_) async =>
            fail('The existing mark must not be searched again'),
        applyDecorations: apply,
      );
      expect(second.highlights, 0);
      expect(second.notes, 0);
      expect(second.visualHighlights, 0);
      expect(await AnnotationStorage().loadHighlights(book.id), hasLength(1));
      expect(applyCalls, 1);
    },
  );

  test('keeps text and notes when a quote has an ambiguous location', () async {
    final importer = FreeWiseImporter();
    final result = await importer.importEntries(
      book,
      importer.parseForBook(book, csv),
      search: (_) async => [
        TextSearchResult(locator: locator),
        TextSearchResult(locator: locator),
      ],
      applyDecorations: (_) async =>
          fail('Ambiguous quotes must stay unmarked'),
    );

    expect(result.highlights, 1);
    expect(result.notes, 1);
    expect(result.visualHighlights, 0);
    expect(result.unlocated, 1);
    expect(await ReadiumStorage().loadDecorations(book.id), isEmpty);
  });

  test('rejects a CSV with no FreeWise columns', () {
    expect(
      () => FreeWiseImporter().parseForBook(book, 'title,text\nA,B'),
      throwsFormatException,
    );
  });

  test('allows choosing a FreeWise title after the EPUB title changed', () {
    final importer = FreeWiseImporter();
    expect(importer.bookTitles(csv), ['Mi libro', 'Otro libro']);
    final entries = importer.parseForBook(book, csv, sourceTitle: 'Otro libro');
    expect(entries.single.text, 'Otro texto');
  });
}
