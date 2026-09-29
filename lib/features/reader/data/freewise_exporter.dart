import 'dart:convert';
import 'dart:typed_data';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'annotation_storage.dart';
import 'readium_storage.dart';

class FreeWiseExporter {
  Future<Uint8List?> buildCsvBytes(EpubBook book, {DateTime? since}) async {
    final csv = await buildCsv(book, since: since);
    return csv == null ? null : Uint8List.fromList(utf8.encode(csv));
  }

  Future<String?> buildCsv(EpubBook book, {DateTime? since}) async {
    final rows = await _buildRows(book, since: since);
    if (rows.length == 1) return null;
    return const ListToCsvConverter().convert(rows);
  }

  Future<int?> exportBook(EpubBook book) async {
    final csv = await buildCsv(book);
    if (csv == null) return 0;

    final rows = await _buildRows(book);
    final savedPath = await FilePicker.saveFile(
      dialogTitle: 'Exportar anotaciones a FreeWise',
      fileName: _fileName(book),
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    return savedPath == null ? null : rows.length - 1;
  }

  Future<List<List<String>>> _buildRows(
    EpubBook book, {
    DateTime? since,
  }) async {
    final highlights = await AnnotationStorage().loadHighlights(book.id);
    // Las copias antiguas de Nextcloud solo contienen las marcas de Readium.
    final storage = ReadiumStorage();
    final decorations = await storage.loadDecorations(book.id);
    final modifiedAt = await storage.loadDecorationsModifiedAt(book.id);
    for (final decoration in decorations) {
      final text = decoration.locator.text?.highlight ?? '';
      if (text.isEmpty ||
          highlights.any(
            (item) =>
                'highlight_${item.id}' == decoration.id || item.text == text,
          )) {
        continue;
      }
      final index = book.chapters.indexWhere(
        (chapter) =>
            decoration.locator.href.endsWith(chapter.filePath) ||
            chapter.filePath.endsWith(decoration.locator.href),
      );
      highlights.add(
        Highlight(
          id: decoration.id,
          bookId: book.id,
          chapterIndex: index < 0 ? 0 : index,
          text: text,
          color: decoration.style.tint ?? const Color(0xFFFFF176),
          createdAt: modifiedAt,
          modifiedAt: modifiedAt,
        ),
      );
    }
    final allNotes = await AnnotationStorage().loadNotes(book.id);
    final notes = since == null
        ? allNotes
        : allNotes.where((note) => note.createdAt.isAfter(since)).toList();
    final notesByText = <String, List<Note>>{};

    for (final note in notes) {
      notesByText.putIfAbsent(note.selectedText, () => []).add(note);
    }

    final rows = <List<String>>[
      [
        'Highlight',
        'Book Title',
        'Book Author',
        'Amazon Book ID',
        'Note',
        'Color',
        'Tags',
        'Location Type',
        'Location',
        'Highlighted at',
        'Document tags',
        'is_favorited',
        'is_discarded',
      ],
    ];

    for (final highlight in highlights) {
      final matchingNotes = notesByText[highlight.text] ?? const <Note>[];
      if (since != null &&
          !highlight.createdAt.isAfter(since) &&
          matchingNotes.isEmpty) {
        continue;
      }
      final note = matchingNotes.isEmpty ? '' : matchingNotes.first.content;
      rows.add(
        _row(
          book,
          highlight.text,
          note,
          highlight.chapterIndex,
          highlight.createdAt,
        ),
      );
      if (matchingNotes.isNotEmpty) matchingNotes.removeAt(0);
    }

    for (final notesForText in notesByText.values) {
      for (final note in notesForText) {
        rows.add(
          _row(
            book,
            note.selectedText,
            note.content,
            note.chapterIndex,
            note.createdAt,
          ),
        );
      }
    }
    return rows;
  }

  List<String> _row(
    EpubBook book,
    String text,
    String note,
    int chapterIndex,
    DateTime createdAt,
  ) {
    return [
      text,
      book.metadata.title,
      book.metadata.creator ?? '',
      '',
      note,
      '',
      '',
      'order',
      chapterIndex.toString(),
      createdAt.toUtc().toIso8601String(),
      '',
      'false',
      'false',
    ];
  }

  String _fileName(EpubBook book) {
    final safeTitle = book.metadata.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúüñÁÉÍÓÚÜÑ _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return 'edureader_${safeTitle.isEmpty ? 'highlights' : safeTitle}.csv';
  }
}
