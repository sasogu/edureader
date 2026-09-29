import 'package:edureader/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'abre y cierra configuración repetidamente',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale(
        'es',
        'ES',
      );
      SharedPreferences.setMockInitialValues({'app_language': 'es'});
      await tester.pumpWidget(const EduReaderApp());
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(find.text('Configuración'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'guarda la URL y permite volver a abrir configuración',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale(
        'es',
        'ES',
      );
      SharedPreferences.setMockInitialValues({'app_language': 'es'});
      await tester.pumpWidget(const EduReaderApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'http://example.test:8063',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('http://example.test:8063'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Configuración'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Configuración'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('detecta catalán y permite elegir inglés manualmente', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'ca',
      'ES',
    );
    SharedPreferences.setMockInitialValues({'app_language': 'ca'});
    await tester.pumpWidget(const EduReaderApp());
    await tester.pumpAndSettle();

    expect(find.text('Tria un EPUB'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Configuració'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desa'));
    await tester.pumpAndSettle();

    expect(find.text('Choose an EPUB'), findsOneWidget);
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
