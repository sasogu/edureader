import 'package:edureader/features/library/data/incoming_epub_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('edureader/test-documents');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('imports a staged EPUB and discards its temporary copy', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'pendingDocuments') return ['/cache/book.epub'];
          if (call.method == 'discardDocument') {
            calls.add('discard:${call.arguments}');
            return true;
          }
          return null;
        });
    final service = IncomingEpubService(channel: channel);

    await service.start((path) async => calls.add('import:$path'));

    expect(calls, ['import:/cache/book.epub', 'discard:/cache/book.epub']);
    service.dispose();
  });

  test('retains a staged EPUB when import fails', () async {
    var discarded = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'pendingDocuments') return ['/cache/book.epub'];
          if (call.method == 'discardDocument') discarded = true;
          return null;
        });
    final service = IncomingEpubService(channel: channel);

    await service.start((_) async => throw StateError('invalid EPUB'));

    expect(discarded, isFalse);
    service.dispose();
  });

  test('imports an EPUB opened while the app is running', () async {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pendingDocuments') return <String>[];
      if (call.method == 'discardDocument') {
        calls.add('discard:${call.arguments}');
        return true;
      }
      return null;
    });
    final service = IncomingEpubService(channel: channel);
    await service.start((path) async => calls.add('import:$path'));

    final reply = messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('documentOpened', '/cache/live.epub'),
      ),
      (_) {},
    );
    await reply;

    expect(calls, ['import:/cache/live.epub', 'discard:/cache/live.epub']);
    service.dispose();
  });
}
