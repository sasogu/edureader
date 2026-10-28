import 'package:shared_preferences/shared_preferences.dart';

/// Identifies a reading position by PDF contents, so reimporting the same
/// document restores it even when the imported filename changes.
class PdfReadingPosition {
  static String _key(String contentHash) => 'pdf_page_hash_$contentHash';

  static Future<int?> load(String contentHash, String documentId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_key(contentHash));
    if (saved != null) return saved;
    final legacy = prefs.getInt('pdf_page_$documentId');
    if (legacy != null) await prefs.setInt(_key(contentHash), legacy);
    return legacy;
  }

  static Future<void> save(String contentHash, int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(contentHash), page);
  }
}
