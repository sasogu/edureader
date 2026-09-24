import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'freewise_exporter.dart';

class FreeWiseSync {
  static const _urlKey = 'freewise_base_url';
  static const _lastSyncPrefix = 'freewise_last_sync_';

  final FreeWiseExporter _exporter = FreeWiseExporter();

  Future<String?> getBaseUrl() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_urlKey);
  }

  Future<void> setBaseUrl(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_urlKey, _normalise(value));
  }

  Future<int> syncBook(EpubBook book) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw StateError('Configura primero la URL de FreeWise.');
    }

    final preferences = await SharedPreferences.getInstance();
    final lastSyncValue = preferences.getString(_lastSyncKey(book.id));
    final lastSync = lastSyncValue == null
        ? null
        : DateTime.tryParse(lastSyncValue);
    final syncStartedAt = DateTime.now().toUtc();
    final bytes = await _exporter.buildCsvBytes(book, since: lastSync);
    if (bytes == null) return 0;

    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/import/ui/readwise'))
          ..fields['diagnostic'] = 'false'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: 'edureader_highlights.csv',
            ),
          );

    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('FreeWise respondió con HTTP ${response.statusCode}.');
    }
    await preferences.setString(
      _lastSyncKey(book.id),
      syncStartedAt.toIso8601String(),
    );
    return 1;
  }

  String _lastSyncKey(String bookId) => '$_lastSyncPrefix$bookId';

  String _normalise(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
