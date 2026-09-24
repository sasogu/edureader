import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xff315c72);

  static ThemeData get light {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff7f8f9),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero, elevation: 0),
    );
  }

  static ThemeData get dark => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xff121212),
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero, elevation: 0),
  );
}
