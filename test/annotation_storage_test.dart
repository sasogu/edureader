import 'dart:convert';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:edureader/features/reader/data/annotation_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'saving in another book preserves legacy notes and highlights',
    () async {
      final firstNote = Note.create(
        bookId: 'first',
        chapterIndex: 1,
        selectedText: 'Primero',
        content: 'Nota original',
      );
      final firstHighlight = Highlight.create(
        bookId: 'first',
        chapterIndex: 1,
        text: 'Primero',
        color: Colors.yellow,
      );
      SharedPreferences.setMockInitialValues({
        'epub_notes': jsonEncode([firstNote.toJson()]),
        'epub_highlights': jsonEncode([firstHighlight.toJson()]),
      });
      final storage = AnnotationStorage();
      await Future.wait([
        storage.saveNote(
          firstNote.copyWith(bookId: 'second', content: 'Segunda nota'),
        ),
        storage.saveHighlight(
          firstHighlight.copyWith(bookId: 'second', text: 'Segundo'),
        ),
      ]);
      expect(
        (await storage.loadNotes('first')).single.content,
        'Nota original',
      );
      expect((await storage.loadHighlights('first')).single.text, 'Primero');
      await storage.deleteHighlight('second', firstHighlight.id);
      expect(await storage.loadHighlights('first'), hasLength(1));
      expect(await storage.loadHighlights('second'), isEmpty);
    },
  );

  test(
    'merges notes without duplicates and preserves newer local edits',
    () async {
      final storage = AnnotationStorage();
      final note = Note.create(
        bookId: 'book',
        chapterIndex: 0,
        selectedText: 'Texto',
        content: 'Original',
      );
      await storage.saveNote(note);
      final updated = note.copyWith(
        content: 'Revisada',
        modifiedAt: note.modifiedAt.add(const Duration(seconds: 1)),
      );
      await storage.saveNote(updated);
      await storage.mergeNotes('book', [note, updated]);
      final result = await storage.loadNotes('book');
      expect(result, hasLength(1));
      expect(result.single.content, 'Revisada');
    },
  );
}
