import 'dart:convert';

import 'package:flutter_readium/flutter_readium.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader_bookmark.dart';

class ReadiumStorage {
  Future<Locator?> loadLocator(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_locatorKey(bookId));
    return value == null ? null : Locator.fromJsonString(value);
  }

  Future<void> saveLocator(String bookId, Locator locator) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _locatorKey(bookId),
      jsonEncode(locator.toJson()),
    );
    await _touchState(preferences, bookId);
  }

  Future<List<ReaderDecoration>> loadDecorations(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_decorationsKey(bookId));
    if (value == null) return [];

    try {
      final items = jsonDecode(value) as List<dynamic>;
      return items
          .map(
            (item) => ReaderDecoration.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDecorations(
    String bookId,
    List<ReaderDecoration> decorations,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _decorationsKey(bookId),
      jsonEncode(decorations.map((decoration) => decoration.toJson()).toList()),
    );
  }

  Future<List<ReaderBookmark>> loadBookmarks(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_bookmarksKey(bookId));
    if (value == null) return [];

    try {
      final items = jsonDecode(value) as List<dynamic>;
      return items
          .map((item) => ReaderBookmark.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBookmarks(
    String bookId,
    List<ReaderBookmark> bookmarks,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _bookmarksKey(bookId),
      jsonEncode(bookmarks.map((bookmark) => bookmark.toJson()).toList()),
    );
    await _touchState(preferences, bookId);
  }

  Future<DateTime> loadStateModifiedAt(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_stateModifiedKey(bookId));
    return DateTime.tryParse(value ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Future<void> applyRemoteState({
    required String bookId,
    required Map<String, dynamic>? locator,
    required List<dynamic>? bookmarks,
    required DateTime modifiedAt,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    if (locator != null) {
      await preferences.setString(_locatorKey(bookId), jsonEncode(locator));
    }
    if (bookmarks != null) {
      await preferences.setString(_bookmarksKey(bookId), jsonEncode(bookmarks));
    }
    await preferences.setString(
      _stateModifiedKey(bookId),
      modifiedAt.toUtc().toIso8601String(),
    );
  }

  Future<void> _touchState(SharedPreferences preferences, String bookId) =>
      preferences.setString(
        _stateModifiedKey(bookId),
        DateTime.now().toUtc().toIso8601String(),
      );

  String _locatorKey(String bookId) => 'readium_locator_$bookId';

  String _decorationsKey(String bookId) => 'readium_decorations_$bookId';

  String _bookmarksKey(String bookId) => 'readium_bookmarks_$bookId';

  String _stateModifiedKey(String bookId) => 'readium_state_modified_$bookId';
}
