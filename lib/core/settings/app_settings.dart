import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _highlightColorKey = 'reader_highlight_color';
  Color _highlightColor = const Color(0xFFFFF176);
  Color get highlightColor => _highlightColor;

  Future<void> setHighlightColor(Color color) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_highlightColorKey, color.toARGB32());
    _highlightColor = color;
    notifyListeners();
  }

  // ---- Underline color support ----
  static const _underlineColorKey = 'reader_underline_color';
  Color _underlineColor = const Color(0xFF90CAF9); // Azul por defecto
  Color get underlineColor => _underlineColor;

  Future<void> setUnderlineColor(Color color) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_underlineColorKey, color.toARGB32());
    _underlineColor = color;
    notifyListeners();
  }

  static const _darkModeKey = 'appearance_dark_mode';
  static const _sepiaModeKey = 'reader_sepia_mode';
  static const _fontScaleKey = 'reader_font_scale';
  static const _lineHeightKey = 'reader_line_height';
  static const _pageMarginsKey = 'reader_page_margins';

  bool _darkMode = false;
  bool _sepiaMode = false;
  double _fontScale = 1.0;
  double _lineHeight = 1.4;
  double _pageMargins = 1.0;

  bool get darkMode => _darkMode;
  bool get sepiaMode => _sepiaMode;
  double get fontScale => _fontScale;
  double get lineHeight => _lineHeight;
  double get pageMargins => _pageMargins;

  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  EPUBPreferences get epubPreferences => EPUBPreferences(
    scroll: false,
    fontSize: _fontScale,
    lineHeight: _lineHeight,
    pageMargins: _pageMargins,
    backgroundColor: _darkMode
        ? const Color(0xff121212)
        : _sepiaMode
        ? const Color(0xfff1e7d0)
        : const Color(0xfff7f4ed),
    textColor: _darkMode
        ? const Color(0xffeeeeee)
        : _sepiaMode
        ? const Color(0xff493d2b)
        : const Color(0xff202124),
    publisherStyles: false,
  );

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _highlightColor = Color(
      preferences.getInt(_highlightColorKey) ?? 0xFFFFF176,
    );
    _underlineColor = Color(
      preferences.getInt(_underlineColorKey) ?? 0xFF90CAF9,
    );
    _darkMode = preferences.getBool(_darkModeKey) ?? false;
    _sepiaMode = preferences.getBool(_sepiaModeKey) ?? false;
    if (_darkMode) _sepiaMode = false;
    _fontScale = (preferences.getDouble(_fontScaleKey) ?? 1.0)
        .clamp(0.8, 1.8)
        .toDouble();
    _lineHeight = (preferences.getDouble(_lineHeightKey) ?? 1.4)
        .clamp(1.0, 2.0)
        .toDouble();
    _pageMargins = (preferences.getDouble(_pageMarginsKey) ?? 1.0)
        .clamp(0.5, 2.0)
        .toDouble();
    notifyListeners();
  }

  Future<void> updateAppearance({
    required bool darkMode,
    required bool sepiaMode,
    required double fontScale,
    required double lineHeight,
    required double pageMargins,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    _darkMode = darkMode;
    _sepiaMode = darkMode ? false : sepiaMode;
    _fontScale = fontScale.clamp(0.8, 1.8).toDouble();
    _lineHeight = lineHeight.clamp(1.0, 2.0).toDouble();
    _pageMargins = pageMargins.clamp(0.5, 2.0).toDouble();
    await Future.wait([
      preferences.setBool(_darkModeKey, _darkMode),
      preferences.setBool(_sepiaModeKey, _sepiaMode),
      preferences.setDouble(_fontScaleKey, _fontScale),
      preferences.setDouble(_lineHeightKey, _lineHeight),
      preferences.setDouble(_pageMarginsKey, _pageMargins),
    ]);
    notifyListeners();
  }
}
