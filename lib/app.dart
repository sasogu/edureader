import 'package:flutter/material.dart';

import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/library/presentation/library_page.dart';
import 'l10n/app_localizations.dart';

class EduReaderApp extends StatefulWidget {
  const EduReaderApp({super.key});

  @override
  State<EduReaderApp> createState() => _EduReaderAppState();
}

class _EduReaderAppState extends State<EduReaderApp> {
  final AppSettings _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _settings.themeMode,
        locale: _settings.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: (preferredLocales, supportedLocales) {
          for (final preferred in preferredLocales ?? const <Locale>[]) {
            for (final supported in supportedLocales) {
              if (preferred.languageCode == supported.languageCode) {
                return supported;
              }
            }
          }
          return const Locale('es');
        },
        home: LibraryPage(settings: _settings),
      ),
    );
  }
}
