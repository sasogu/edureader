import 'package:edureader/features/reader/presentation/read_aloud_mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> calls;

  Widget player({bool isPlaying = false, bool isBusy = false}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: ReadAloudMiniPlayer(
          isPlaying: isPlaying,
          isBusy: isBusy,
          speed: 1,
          onTogglePlayback: () => calls.add('toggle'),
          onSkip: (forward) => calls.add(forward ? 'next' : 'previous'),
          onSpeedChanged: (speed) => calls.add('speed'),
          onClose: () => calls.add('close'),
          onMove: (up) => calls.add(up ? 'up' : 'down'),
        ),
      ),
    ),
  );

  setUp(() => calls = []);

  test('1.0× reads at the slower base rate', () {
    expect(ttsEngineRate(1), 0.8);
    expect(ttsEngineRate(2), closeTo(1.6, 1e-9));
  });

  testWidgets('play button follows the playback state', (tester) async {
    await tester.pumpWidget(player());
    expect(find.byTooltip('Reproducir'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.pumpWidget(player(isPlaying: true));
    expect(find.byTooltip('Pausar'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('buttons call their callbacks', (tester) async {
    await tester.pumpWidget(player());
    await tester.tap(find.byTooltip('Frase anterior'));
    await tester.tap(find.byTooltip('Reproducir'));
    await tester.tap(find.byTooltip('Frase siguiente'));
    await tester.tap(find.byTooltip('Cerrar lectura en voz alta'));
    expect(calls, ['previous', 'toggle', 'next', 'close']);
  });

  testWidgets('play is disabled while busy', (tester) async {
    await tester.pumpWidget(player(isBusy: true));
    await tester.tap(find.byTooltip('Reproducir'));
    expect(calls, isEmpty);
  });

  testWidgets('speed button reveals an inline slider', (tester) async {
    await tester.pumpWidget(player());
    expect(find.byType(Slider), findsNothing);
    await tester.tap(find.text('1.0×'));
    await tester.pump();
    expect(find.byType(Slider), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump();
    expect(calls, ['speed']);
    expect(find.text('1.0×'), findsNothing);
  });

  testWidgets('flinging moves the player up or down', (tester) async {
    await tester.pumpWidget(player());
    final handle = find.byIcon(Icons.record_voice_over_outlined);
    await tester.fling(handle, const Offset(0, -150), 800);
    await tester.pumpAndSettle();
    await tester.fling(handle, const Offset(0, 150), 800);
    await tester.pumpAndSettle();
    expect(calls, ['up', 'down']);
  });
}
