import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

/// Extrae la imagen de portada de un EPUB siguiendo el paquete OPF:
/// `properties="cover-image"` (EPUB 3), `<meta name="cover">` (EPUB 2) y,
/// como último recurso, una imagen del manifiesto cuyo id o ruta diga «cover».
Uint8List? extractEpubCover(List<int> epubBytes) {
  final archive = ZipDecoder().decodeBytes(epubBytes);
  final container = archive.findFile('META-INF/container.xml');
  if (container == null) return null;
  final opfPath = XmlDocument.parse(utf8.decode(container.content as List<int>))
      .findAllElements('rootfile')
      .map((element) => element.getAttribute('full-path'))
      .whereType<String>()
      .firstOrNull;
  if (opfPath == null) return null;
  final opfFile = archive.findFile(opfPath);
  if (opfFile == null) return null;

  final opf = XmlDocument.parse(utf8.decode(opfFile.content as List<int>));
  final items = opf
      .findAllElements('item')
      .where(
        (item) =>
            (item.getAttribute('media-type') ?? '').startsWith('image/') &&
            item.getAttribute('href') != null,
      )
      .toList();
  if (items.isEmpty) return null;

  final coverId = opf
      .findAllElements('meta')
      .where((meta) => meta.getAttribute('name') == 'cover')
      .map((meta) => meta.getAttribute('content'))
      .whereType<String>()
      .firstOrNull;

  XmlElement? cover = items
      .where(
        (item) => (item.getAttribute('properties') ?? '')
            .split(' ')
            .contains('cover-image'),
      )
      .firstOrNull;
  cover ??= items
      .where((item) => coverId != null && item.getAttribute('id') == coverId)
      .firstOrNull;
  cover ??= items.where((item) {
    final id = (item.getAttribute('id') ?? '').toLowerCase();
    final href = item.getAttribute('href')!.toLowerCase();
    return id.contains('cover') || href.contains('cover');
  }).firstOrNull;
  if (cover == null) return null;

  final href = Uri.decodeFull(cover.getAttribute('href')!);
  final imagePath = p.posix.normalize(
    p.posix.join(p.posix.dirname(opfPath), href),
  );
  final image = archive.findFile(imagePath);
  if (image == null) return null;
  return Uint8List.fromList(image.content as List<int>);
}

/// Guarda en disco la portada de cada EPUB para no descomprimir el libro cada
/// vez que se abre la biblioteca. Un fichero `.none` recuerda los libros sin
/// portada.
class CoverCache {
  CoverCache({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;
  final Map<String, Future<File?>> _pending = {};

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'covers'),
  );

  Future<File?> coverFor(String epubPath) =>
      _pending.putIfAbsent(epubPath, () => _load(epubPath));

  Future<File?> _load(String epubPath) async {
    final directory = await _directory();
    final key = sha1.convert(utf8.encode(epubPath)).toString();
    final image = File(p.join(directory.path, '$key.img'));
    final missing = File(p.join(directory.path, '$key.none'));
    if (await image.exists()) return image;
    if (await missing.exists()) return null;

    Uint8List? bytes;
    try {
      bytes = await Isolate.run(
        () => extractEpubCover(File(epubPath).readAsBytesSync()),
      );
    } catch (_) {
      // Un EPUB con el paquete dañado se muestra sin portada.
      bytes = null;
    }
    await directory.create(recursive: true);
    if (bytes == null || bytes.isEmpty) {
      await missing.writeAsString('');
      return null;
    }
    await image.writeAsBytes(bytes, flush: true);
    return image;
  }
}
