// Recorre la app con una biblioteca de ejemplo para las capturas de las
// tiendas. No hace capturas por sí mismo: imprime `EDUREADER_SHOT:<nombre>` y
// espera unos segundos para que `tool/store_screenshots.sh` capture la
// pantalla del simulador, que así incluye las vistas nativas de Readium.
//
// flutter test integration_test/store_screenshots_test.dart \
//   --dart-define=SCREENSHOT_EPUBS=/ruta/a/epubs -d <simulador>
import 'dart:io';

import 'package:edureader/app.dart';
import 'package:edureader/features/library/data/library_storage.dart';
import 'package:edureader/features/reader/presentation/reader_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

const _epubDirectory = String.fromEnvironment('SCREENSHOT_EPUBS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    expect(_epubDirectory, isNotEmpty, reason: 'Falta SCREENSHOT_EPUBS');

    Future<void> wait(int milliseconds) async {
      final end = DateTime.now().add(Duration(milliseconds: milliseconds));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    Future<void> shot(String name) async {
      await wait(1500);
      // ignore: avoid_print
      print('EDUREADER_SHOT:$name');
      await wait(3000);
    }

    Future<void> tap(Finder finder) async {
      await tester.tap(finder.first);
      await wait(1200);
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    final storage = LibraryStorage();
    final epubs =
        Directory(_epubDirectory)
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.epub'))
            .toList()
          ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    for (final epub in epubs) {
      await storage.importBook(epub.path);
    }

    await tester.pumpWidget(const EduReaderApp());
    await wait(4000);
    await shot('01_biblioteca');

    await tap(find.textContaining('Quijote'));
    await wait(5000);
    await tap(find.byTooltip('Índice del libro'));
    await shot('03_indice');
    await tap(find.textContaining('Capítulo primero'));
    await wait(3000);
    await shot('02_lectura');

    final settings = tester
        .widget<ReaderPage>(find.byType(ReaderPage))
        .settings;
    Future<void> theme({required bool dark, required bool sepia}) =>
        settings.updateAppearance(
          darkMode: dark,
          sepiaMode: sepia,
          fontScale: settings.fontScale,
          lineHeight: settings.lineHeight,
          pageMargins: settings.pageMargins,
        );
    await theme(dark: false, sepia: true);
    await wait(2000);
    await tap(find.byTooltip('Apariencia de lectura'));
    await shot('04_apariencia');
    await tap(find.text('Cancelar'));

    await tap(find.byTooltip('Más opciones'));
    await tap(find.text('Lectura en voz alta'));
    await wait(3000);
    await shot('05_voz_alta');
    await tap(find.byTooltip('Cerrar lectura en voz alta'));

    await theme(dark: true, sepia: false);
    await wait(2000);
    await tap(find.byTooltip('Buscar en el libro'));
    await tester.enterText(find.byType(TextField), 'Dulcinea');
    await tap(find.text('Buscar'));
    await wait(4000);
    await shot('06_busqueda');
    await tap(find.byTooltip('Cerrar resultados'));
    await shot('07_modo_oscuro');

    await theme(dark: false, sepia: false);
    await tap(find.byType(BackButton));
    await wait(2000);
    await tap(find.byTooltip('Sincronización Nextcloud'));
    await wait(1500);
    await shot('08_nextcloud');
  });
}
