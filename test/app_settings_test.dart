import 'package:edureader/core/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists dark mode and reader font scale', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();

    await settings.updateAppearance(darkMode: true, fontScale: 1.4);
    final restoredSettings = AppSettings();
    await restoredSettings.load();

    expect(restoredSettings.themeMode, ThemeMode.dark);
    expect(restoredSettings.fontScale, 1.4);
    expect(restoredSettings.epubPreferences.fontSize, 1.4);
    expect(restoredSettings.epubPreferences.publisherStyles, isFalse);

    settings.dispose();
    restoredSettings.dispose();
  });
}
