import 'package:edureader/core/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists reader appearance preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();

    await settings.updateAppearance(
      darkMode: true,
      sepiaMode: true,
      fontScale: 1.4,
      lineHeight: 1.7,
      pageMargins: 1.5,
      justifyText: true,
    );
    final restoredSettings = AppSettings();
    await restoredSettings.load();

    expect(restoredSettings.themeMode, ThemeMode.dark);
    expect(restoredSettings.fontScale, 1.4);
    expect(restoredSettings.sepiaMode, isFalse);
    expect(restoredSettings.lineHeight, 1.7);
    expect(restoredSettings.pageMargins, 1.5);
    expect(restoredSettings.justifyText, isTrue);
    expect(restoredSettings.epubPreferences.fontSize, 1.4);
    expect(restoredSettings.epubPreferences.lineHeight, 1.7);
    expect(restoredSettings.epubPreferences.pageMargins, 1.5);
    expect(restoredSettings.epubPreferences.publisherStyles, isFalse);
    expect(restoredSettings.epubPreferences.textAlign, TextAlign.justify);

    settings.dispose();
    restoredSettings.dispose();
  });

  test('supports font sizes up to 250 percent', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();

    await settings.updateAppearance(
      darkMode: false,
      sepiaMode: false,
      fontScale: 2.5,
      lineHeight: 1.4,
      pageMargins: 1,
    );
    final restoredSettings = AppSettings();
    await restoredSettings.load();

    expect(restoredSettings.fontScale, 2.5);
    expect(restoredSettings.epubPreferences.fontSize, 2.5);

    settings.dispose();
    restoredSettings.dispose();
  });
}
