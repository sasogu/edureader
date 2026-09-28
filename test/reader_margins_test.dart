import 'package:edureader/core/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the vertical page margin follows the margins setting', () async {
    final settings = AppSettings();
    await settings.load();
    expect(settings.verticalPageMargin, greaterThanOrEqualTo(24));

    Future<void> setMargins(double value) => settings.updateAppearance(
      darkMode: false,
      sepiaMode: false,
      fontScale: 1,
      lineHeight: 1.4,
      pageMargins: value,
    );

    await setMargins(0.5);
    final narrow = settings.verticalPageMargin;
    await setMargins(2);
    expect(settings.verticalPageMargin, greaterThan(narrow));
    expect(narrow, greaterThan(0));
  });

  test('the margin uses the same background as the page', () async {
    final settings = AppSettings();
    for (final (dark, sepia) in [
      (false, false),
      (false, true),
      (true, false),
    ]) {
      await settings.updateAppearance(
        darkMode: dark,
        sepiaMode: sepia,
        fontScale: 1,
        lineHeight: 1.4,
        pageMargins: 1,
      );
      expect(
        settings.readerBackgroundColor,
        settings.epubPreferences.backgroundColor,
      );
    }
  });
}
