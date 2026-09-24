import 'dart:convert';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReadingProgressStorage {
  Future<ReadingProgress?> load(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key(bookId));
    if (encoded == null) return null;

    try {
      return ReadingProgress.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ReadingProgress progress) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(progress.bookId),
      jsonEncode(progress.toJson()),
    );
  }

  String _key(String bookId) => 'reading_progress_$bookId';
}
