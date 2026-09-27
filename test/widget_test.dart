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
}
