import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _darkModeKey = 'appearance_dark_mode';
  static const _fontScaleKey = 'reader_font_scale';

  bool _darkMode = false;
  double _fontScale = 1.0;

  bool get darkMode => _darkMode;
  double get fontScale => _fontScale;

  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  EPUBPreferences get epubPreferences => EPUBPreferences(
    scroll: false,
    fontSize: _fontScale,
    backgroundColor: _darkMode
        ? const Color(0xff121212)
        : const Color(0xfff7f4ed),
    textColor: _darkMode ? const Color(0xffeeeeee) : const Color(0xff202124),
    publisherStyles: false,
  );

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _darkMode = preferences.getBool(_darkModeKey) ?? false;
    _fontScale = (preferences.getDouble(_fontScaleKey) ?? 1.0)
        .clamp(0.8, 1.8)
        .toDouble();
    notifyListeners();
  }

  Future<void> updateAppearance({
    required bool darkMode,
    required double fontScale,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    _darkMode = darkMode;
    _fontScale = fontScale.clamp(0.8, 1.8).toDouble();
    await Future.wait([
      preferences.setBool(_darkModeKey, _darkMode),
      preferences.setDouble(_fontScaleKey, _fontScale),
    ]);
    notifyListeners();
  }
}
