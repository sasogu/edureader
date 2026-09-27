import 'package:edureader/core/settings/app_settings.dart';
import 'package:edureader/core/widgets/completed_dialog.dart';
import 'package:edureader/features/reader/presentation/highlight_color_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('elige un color y lo recuerda al reiniciar los ajustes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                final color = await showCompletedDialog<Color>(
                  context: context,
                  builder: (_) => HighlightColorDialog(
                    initialColor: settings.highlightColor,
                  ),
                );
                if (color != null) await settings.setHighlightColor(color);
              },
              child: const Text('Elegir'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Elegir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Azul'));
    await tester.tap(find.text('Subrayar'));
    await tester.pumpAndSettle();
    final restored = AppSettings();
    await restored.load();
    expect(restored.highlightColor, highlightColors['Azul']);
    await tester.tap(find.text('Elegir'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Azul'))
          .selected,
      isTrue,
    );
    await tester.tap(find.text('Rosa'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(settings.highlightColor, highlightColors['Azul']);
    expect(tester.takeException(), isNull);
    settings.dispose();
    restored.dispose();
  });
}
