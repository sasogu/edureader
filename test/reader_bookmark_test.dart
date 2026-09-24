import 'package:edureader/features/reader/data/reader_bookmark.dart';
import 'package:edureader/features/reader/data/readium_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists bookmarks independently for each book', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = ReadiumStorage();
    final bookmark = ReaderBookmark.create(
      locator: const Locator(
        href: 'text/chapter-2.xhtml',
        type: 'application/xhtml+xml',
        title: 'Capítulo dos',
        locations: Locations(
          progression: 0.4,
          totalProgression: 0.25,
          position: 2,
        ),
      ),
      label: 'Pasaje importante',
    );

    await storage.saveBookmarks('book-a', [bookmark]);
    final restored = await storage.loadBookmarks('book-a');

    expect(restored, hasLength(1));
    expect(restored.single.id, bookmark.id);
    expect(restored.single.label, 'Pasaje importante');
    expect(restored.single.locator.href, 'text/chapter-2.xhtml');
    expect(restored.single.locator.locations?.progression, 0.4);
    expect(await storage.loadBookmarks('book-b'), isEmpty);
  });
}
