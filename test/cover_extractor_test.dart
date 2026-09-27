import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edureader/features/library/data/cover_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

const _container = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';

List<int> _epub(String manifest, Map<String, List<int>> files) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('META-INF/container.xml', _container))
    ..addFile(
      ArchiveFile.string(
        'OEBPS/content.opf',
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
            '$manifest</package>',
      ),
    );
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return ZipEncoder().encode(archive)!;
}

void main() {
  final image = [1, 2, 3, 4];
  final other = [9, 9];

  test('uses the EPUB 3 cover-image property', () {
    final bytes = _epub(
      '<manifest>'
      '<item id="cover-page" href="cover.xhtml" media-type="application/xhtml+xml"/>'
      '<item id="a" href="images/other.png" media-type="image/png"/>'
      '<item id="b" href="images/front.jpg" media-type="image/jpeg" properties="cover-image"/>'
      '</manifest>',
      {'OEBPS/images/other.png': other, 'OEBPS/images/front.jpg': image},
    );

    expect(extractEpubCover(bytes), image);
  });

  test('uses the EPUB 2 cover meta and resolves relative, encoded hrefs', () {
    final bytes = _epub(
      '<metadata><meta name="cover" content="portada"/></metadata>'
      '<manifest>'
      '<item id="x" href="../Images/other.png" media-type="image/png"/>'
      '<item id="portada" href="../Images/la%20portada.jpg" media-type="image/jpeg"/>'
      '</manifest>',
      {'Images/other.png': other, 'Images/la portada.jpg': image},
    );

    expect(extractEpubCover(bytes), image);
  });

  test('never returns the XHTML cover page and falls back to null', () {
    final bytes = _epub(
      '<manifest>'
      '<item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>'
      '<item id="pic" href="pic.png" media-type="image/png"/>'
      '</manifest>',
      {'OEBPS/cover.xhtml': utf8.encode('<html/>'), 'OEBPS/pic.png': other},
    );

    expect(extractEpubCover(bytes), isNull);
  });

  test('caches covers on disk and remembers books without one', () async {
    final directory = await Directory.systemTemp.createTemp('edureader-cov-');
    addTearDown(() => directory.delete(recursive: true));
    final withCover = File('${directory.path}/a.epub')
      ..writeAsBytesSync(
        _epub(
          '<manifest><item id="c" href="c.jpg" media-type="image/jpeg" '
          'properties="cover-image"/></manifest>',
          {'OEBPS/c.jpg': image},
        ),
      );
    final withoutCover = File('${directory.path}/b.epub')
      ..writeAsBytesSync(_epub('<manifest/>', {}));
    final coversDirectory = Directory('${directory.path}/covers');
    Future<Directory> covers() async => coversDirectory;

    final cover = await CoverCache(directory: covers).coverFor(withCover.path);
    expect(cover!.readAsBytesSync(), image);
    expect(
      await CoverCache(directory: covers).coverFor(withoutCover.path),
      isNull,
    );

    // Otra instancia reutiliza la caché aunque el EPUB ya no exista.
    withCover.deleteSync();
    final cached = await CoverCache(directory: covers).coverFor(withCover.path);
    expect(cached!.readAsBytesSync(), image);
  });
}
