import 'dart:convert';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conserva las claves anteriores, pero modifica solo los registros del libro
/// afectado. Los servicios del parser sobrescribían la colección global.
class AnnotationStorage {
  static Future<void> _queue = Future.value();

  Future<void> _mutate(
    String key,
    void Function(List<Map<String, dynamic>>) update,
  ) {
    final operation = _queue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final records = _decode(preferences.getString(key));
      update(records);
      await preferences.setString(key, jsonEncode(records));
    });
    _queue = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  List<Map<String, dynamic>> _decode(String? value) => value == null
      ? []
      : (jsonDecode(value) as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

  Future<List<Highlight>> loadHighlights(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    return _decode(preferences.getString('epub_highlights'))
        .where((item) => item['bookId'] == bookId)
        .map(Highlight.fromJson)
        .toList();
  }

  Future<List<Note>> loadNotes(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    return _decode(
      preferences.getString('epub_notes'),
    ).where((item) => item['bookId'] == bookId).map(Note.fromJson).toList();
  }

  Future<void> saveHighlight(Highlight highlight) =>
      _mutate('epub_highlights', (items) {
        items.removeWhere(
          (item) =>
              item['bookId'] == highlight.bookId && item['id'] == highlight.id,
        );
        items.add(highlight.toJson());
      });

  Future<void> deleteHighlight(String bookId, String id) => _mutate(
    'epub_highlights',
    (items) {
      items.removeWhere((item) => item['bookId'] == bookId && item['id'] == id);
    },
  );

  Future<void> replaceHighlights(String bookId, List<Highlight> highlights) =>
      _mutate('epub_highlights', (items) {
        items.removeWhere((item) => item['bookId'] == bookId);
        items.addAll(
          highlights.map((item) => item.copyWith(bookId: bookId).toJson()),
        );
      });

  Future<void> saveNote(Note note) => mergeNotes(note.bookId, [note]);

  // Las notas no tienen una acción de borrado en el lector. Se fusionan por ID
  // y fecha para conservar las creadas en distintos dispositivos sin duplicar.
  Future<void> mergeNotes(String bookId, List<Note> notes) =>
      _mutate('epub_notes', (items) {
        for (final note in notes) {
          final index = items.indexWhere(
            (item) => item['bookId'] == bookId && item['id'] == note.id,
          );
          final local = index < 0 ? null : Note.fromJson(items[index]);
          if (local != null && !note.modifiedAt.isAfter(local.modifiedAt)) {
            continue;
          }
          final value = note.copyWith(bookId: bookId).toJson();
          if (index < 0) {
            items.add(value);
          } else {
            items[index] = value;
          }
        }
      });
}
