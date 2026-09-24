import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/library/presentation/library_page.dart';

class EduReaderApp extends StatelessWidget {
  const EduReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduReader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LibraryPage(),
    );
  }
}
