import 'package:flutter/material.dart';

import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/library/presentation/library_page.dart';

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
        title: 'EduReader',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _settings.themeMode,
        home: LibraryPage(settings: _settings),
      ),
    );
  }
}
