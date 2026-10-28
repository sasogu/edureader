import 'dart:convert';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:http/http.dart' as http;

import 'annotation_storage.dart';
import 'readium_storage.dart';

class FreeWiseImportEntry {
  const FreeWiseImportEntry({
    required this.text,
    required this.note,
    required this.bookTitle,
    required this.bookAuthor,
    required this.createdAt,
    this.chapterIndex,
  });

  final String text;
  final String note;
  final String bookTitle;
  final String bookAuthor;
  final DateTime createdAt;
  final int? chapterIndex;
}

class FreeWiseImportResult {
  const FreeWiseImportResult({
    required this.highlights,
    required this.notes,
    required this.visualHighlights,
    required this.unlocated,
  });

  final int highlights;
  final int notes;
  final int visualHighlights;
  final int unlocated;
}

/// Restores FreeWise's CSV text and notes. Readium only gets a visual mark when
/// an exact quote has one unambiguous match in the currently open EPUB.
class FreeWiseImporter {
  FreeWiseImporter({
    AnnotationStorage? annotations,
    ReadiumStorage? readiumStorage,
    http.Client? client,
  }) : _annotations = annotations ?? AnnotationStorage(),
       _readiumStorage = readiumStorage ?? ReadiumStorage(),
       _client = client ?? http.Client();

  final AnnotationStorage _annotations;
  final ReadiumStorage _readiumStorage;
  final http.Client _client;

  Future<String> downloadCsv(String baseUrl) async {
    final response = await _client.get(Uri.parse('$baseUrl/export/csv'));
    if (response.statusCode != 200) {
      throw StateError('FreeWise respondió con HTTP ${response.statusCode}.');
    }
    return utf8.decode(response.bodyBytes);
  }

  List<String> bookTitles(String csv) {
    final rows = _rows(csv);
    final headers = rows.first
        .map((value) => _normalize(value.toString()))
        .toList();
    final titleColumn = headers.indexOf('book title');
    if (titleColumn < 0) {
      throw const FormatException('El archivo no es un CSV de FreeWise.');
    }
    return {
      for (final row in rows.skip(1))
        if (titleColumn < row.length &&
            row[titleColumn].toString().trim().isNotEmpty)
          row[titleColumn].toString().trim(),
    }.toList()..sort();
  }

  List<FreeWiseImportEntry> parseForBook(
    EpubBook book,
    String csv, {
    String? sourceTitle,
  }) {
    final rows = _rows(csv);
    final headers = rows.first
        .map((value) => _normalize(value.toString()))
        .toList();
    final textColumn = headers.indexOf('highlight');
    final titleColumn = headers.indexOf('book title');
    final noteColumn = headers.indexOf('note');
    if (textColumn < 0 || titleColumn < 0 || noteColumn < 0) {
      throw const FormatException('El archivo no es un CSV de FreeWise.');
    }
    final authorColumn = headers.indexOf('book author');
    final locationTypeColumn = headers.indexOf('location type');
    final locationColumn = headers.indexOf('location');
    final dateColumn = headers.indexOf('highlighted at');
    final title = _normalize(sourceTitle ?? book.metadata.title);
    final author = sourceTitle == null
        ? _normalize(book.metadata.creator ?? '')
        : '';
    final entries = <FreeWiseImportEntry>[];

    for (final row in rows.skip(1)) {
      String cell(int index) =>
          index < 0 || index >= row.length ? '' : row[index].toString().trim();
      final text = cell(textColumn);
      final rowTitle = cell(titleColumn);
      final rowAuthor = cell(authorColumn);
      if (text.isEmpty || _normalize(rowTitle) != title) continue;
      if (author.isNotEmpty &&
          rowAuthor.isNotEmpty &&
          _normalize(rowAuthor) != author) {
        continue;
      }
      final chapterIndex = _normalize(cell(locationTypeColumn)) == 'order'
          ? int.tryParse(cell(locationColumn))
          : null;
      entries.add(
        FreeWiseImportEntry(
          text: text,
          note: cell(noteColumn),
          bookTitle: rowTitle,
          bookAuthor: rowAuthor,
          chapterIndex: chapterIndex,
          createdAt:
              DateTime.tryParse(cell(dateColumn)) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      );
    }
    return entries;
  }

  List<List<dynamic>> _rows(String csv) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(csv.replaceFirst('\uFEFF', ''));
    if (rows.isEmpty) throw const FormatException('El CSV está vacío.');
    return rows;
  }

  Future<FreeWiseImportResult> importEntries(
    EpubBook book,
    List<FreeWiseImportEntry> entries, {
    required Future<List<TextSearchResult>> Function(String) search,
    required Future<void> Function(List<ReaderDecoration>) applyDecorations,
  }) async {
    final existingHighlights = await _annotations.loadHighlights(book.id);
    final existingNotes = await _annotations.loadNotes(book.id);
    final highlightIds = existingHighlights.map((item) => item.id).toSet();
    final noteIds = existingNotes.map((item) => item.id).toSet();
    final decorations = await _readiumStorage.loadDecorations(book.id);
    final decorationIds = decorations.map((item) => item.id).toSet();
    var highlights = 0;
    var notes = 0;
    var visualHighlights = 0;
    var unlocated = 0;

    for (final entry in entries) {
      final key = sha1
          .convert(
            utf8.encode(
              '${book.id}\u0000${_normalize(entry.text)}\u0000${entry.chapterIndex ?? ''}\u0000${entry.createdAt.toUtc().toIso8601String()}',
            ),
          )
          .toString();
      final highlightId = 'freewise_$key';
      final decorationId = 'highlight_$highlightId';
      final needsHighlight = !highlightIds.contains(highlightId);
      final needsDecoration = !decorationIds.contains(decorationId);
      TextSearchResult? match;
      if (needsDecoration) {
        List<TextSearchResult> results;
        try {
          results = await search(
            entry.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
          );
        } catch (_) {
          results = const [];
        }
        final exact = results
            .where(
              (result) =>
                  _normalize(result.locator.text?.highlight ?? '') ==
                  _normalize(entry.text),
            )
            .toList();
        if (exact.length == 1) {
          match = exact.single;
        } else if (exact.length > 1 && entry.chapterIndex != null) {
          final inChapter = exact
              .where(
                (result) =>
                    _chapterIndex(book, result.locator) == entry.chapterIndex,
              )
              .toList();
          if (inChapter.length == 1) match = inChapter.single;
        }
        if (match == null) unlocated++;
      }
      final chapterIndex = match == null
          ? entry.chapterIndex ?? 0
          : _chapterIndex(book, match.locator);
      if (needsHighlight) {
        await _annotations.saveHighlight(
          Highlight(
            id: highlightId,
            bookId: book.id,
            chapterIndex: chapterIndex,
            text: entry.text,
            color: Colors.yellow,
            createdAt: entry.createdAt,
            modifiedAt: entry.createdAt,
          ),
        );
        highlightIds.add(highlightId);
        highlights++;
      }
      if (entry.note.isNotEmpty) {
        final noteId =
            'freewise_${sha1.convert(utf8.encode('$key\u0000${entry.note}'))}';
        if (noteIds.add(noteId)) {
          await _annotations.saveNote(
            Note(
              id: noteId,
              bookId: book.id,
              chapterIndex: chapterIndex,
              selectedText: entry.text,
              content: entry.note,
              createdAt: entry.createdAt,
              modifiedAt: entry.createdAt,
            ),
          );
          notes++;
        }
      }
      if (match != null) {
        decorations.add(
          ReaderDecoration(
            id: decorationId,
            locator: match.locator,
            style: const ReaderDecorationStyle(
              style: DecorationStyle.underline,
              tint: Colors.yellow,
            ),
          ),
        );
        decorationIds.add(decorationId);
        visualHighlights++;
      }
    }
    if (visualHighlights > 0) {
      await _readiumStorage.saveDecorations(book.id, decorations);
      await applyDecorations(decorations);
    }
    return FreeWiseImportResult(
      highlights: highlights,
      notes: notes,
      visualHighlights: visualHighlights,
      unlocated: unlocated,
    );
  }

  int _chapterIndex(EpubBook book, Locator locator) {
    final index = book.chapters.indexWhere(
      (chapter) =>
          locator.href.endsWith(chapter.filePath) ||
          chapter.filePath.endsWith(locator.href),
    );
    return index < 0 ? 0 : index;
  }

  String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
