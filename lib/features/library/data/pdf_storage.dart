import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../reader/data/readium_storage.dart';

class PdfDocument {
  const PdfDocument({
    required this.id,
    required this.path,
    required this.title,
  });

  final String id;
  final String path;
  final String title;
}

/// Keeps PDFs in the same private documents directory as EPUBs, but in a
/// separate subdirectory so EPUB recovery and Nextcloud sync never parse them.
class PdfStorage {
  PdfStorage({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  Future<Directory> _pdfDirectory() async =>
      Directory(p.join((await _documentsDirectory()).path, 'pdfs'));

  Future<List<PdfDocument>> loadDocuments() async {
    final directory = await _pdfDirectory();
    if (!await directory.exists()) return [];
    final documents = <PdfDocument>[];
    await for (final entity in directory.list()) {
      if (entity is File && p.extension(entity.path).toLowerCase() == '.pdf') {
        documents.add(_document(entity));
      }
    }
    documents.sort((a, b) => b.id.compareTo(a.id));
    return documents;
  }

  Future<PdfDocument> importDocument(String sourcePath) async {
    final source = File(sourcePath);
    final handle = await source.open();
    try {
      final header = await handle.read(5);
      if (String.fromCharCodes(header) != '%PDF-') {
        throw const FormatException('Invalid PDF header');
      }
    } finally {
      await handle.close();
    }
    final directory = await _pdfDirectory();
    await directory.create(recursive: true);
    final name =
        '${DateTime.now().microsecondsSinceEpoch}_${p.basename(sourcePath)}';
    final destination = File(p.join(directory.path, name));
    await source.copy(destination.path);
    return _document(destination);
  }

  Future<void> removeDocument(PdfDocument document) async {
    final directory = await _pdfDirectory();
    final expected = p.join(directory.path, p.basename(document.path));
    if (p.normalize(document.path) != p.normalize(expected)) return;
    final file = File(document.path);
    if (await file.exists()) await file.delete();
    await ReadiumStorage().removeBookState(document.id);
  }

  PdfDocument _document(File file) {
    final name = p.basename(file.path);
    final originalName = name.replaceFirst(RegExp(r'^\d+_'), '');
    return PdfDocument(
      id: p.join('pdfs', name),
      path: file.path,
      title: p.basenameWithoutExtension(originalName),
    );
  }
}
