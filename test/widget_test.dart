import 'package:edureader/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra la biblioteca vacía', (tester) async {
    await tester.pumpWidget(const EduReaderApp());

    expect(find.text('EduReader'), findsOneWidget);
    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
    expect(find.text('Elegir un EPUB'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets(
    'el menú de Nextcloud sigue abierto hasta elegir una opción',
    (tester) async {
      await tester.pumpWidget(const EduReaderApp());

      await tester.tap(find.byTooltip('Sincronización Nextcloud'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Sincronizar biblioteca'), findsOneWidget);
      expect(find.text('Configurar Nextcloud'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
