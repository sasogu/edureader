import 'dart:convert';
import 'package:edureader/features/reader/data/readium_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final decoration = ReaderDecoration(
    id: 'saved-highlight',
    locator: Locator.fromJson({
      'href': 'text/ch001.xhtml',
      'type': 'application/xhtml+xml',
      'text': {'highlight': 'Texto subrayado'},
      'locations': {'progression': 0.2},
    })!,
    style: const ReaderDecorationStyle(
      style: DecorationStyle.highlight,
      tint: Color(0x80FFF176),
    ),
  );

  test(
    'recupera subrayados existentes guardados con color hexadecimal',
    () async {
      SharedPreferences.setMockInitialValues({
        'readium_decorations_book': jsonEncode([decoration.toJson()]),
      });
      final restored = await ReadiumStorage().loadDecorations('book');
      expect(restored, hasLength(1));
      expect(restored.single.locator.text?.highlight, 'Texto subrayado');
      expect(restored.single.style.tint, decoration.style.tint);
    },
  );

  test(
    'mantiene subrayados al crear una nueva instancia del almacén',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ReadiumStorage().saveDecorations('book', [decoration]);
      final restored = await ReadiumStorage().loadDecorations('book');
      expect(restored, hasLength(1));
      expect(restored.single.toJson(), decoration.toJson());
    },
  );

  test('conserva la fecha remota al restaurar subrayados', () async {
    SharedPreferences.setMockInitialValues({});
    final modifiedAt = DateTime.utc(2026, 9, 29, 10, 30);
    final storage = ReadiumStorage();

    await storage.applyRemoteDecorations(
      bookId: 'book',
      decorations: [decoration],
      modifiedAt: modifiedAt,
    );

    expect(await storage.loadDecorations('book'), hasLength(1));
    expect(await storage.loadDecorationsModifiedAt('book'), modifiedAt);
  });
}
