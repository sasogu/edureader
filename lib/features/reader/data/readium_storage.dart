import 'dart:convert';

import 'package:flutter_readium/flutter_readium.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String _locatorKey(String bookId) => 'readium_locator_$bookId';

  String _decorationsKey(String bookId) => 'readium_decorations_$bookId';
}
