import 'dart:async';

import 'package:flutter/services.dart';

/// Receives EPUBs that iPadOS opens with EduReader. Native code stages each
/// document in the app cache until the library has imported it.
class IncomingEpubService {
  IncomingEpubService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('es.edutictac.edureader/documents');

  final MethodChannel _channel;
  final Set<String> _seen = {};
  Future<void> _queue = Future<void>.value();

  Future<void> start(Future<void> Function(String path) onDocument) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'documentOpened' && call.arguments is String) {
        await _enqueue(call.arguments as String, onDocument);
      }
    });
    try {
      final pending =
          await _channel.invokeListMethod<String>('pendingDocuments') ?? [];
      for (final path in pending) {
        _enqueue(path, onDocument);
      }
      await _queue;
    } on MissingPluginException {
      // Other platforms only use the EPUB picker inside EduReader.
    }
  }

  Future<void> _enqueue(
    String path,
    Future<void> Function(String path) onDocument,
  ) {
    if (!_seen.add(path)) return _queue;
    _queue = _queue.then((_) async {
      try {
        await onDocument(path);
        await _channel.invokeMethod<bool>('discardDocument', path);
      } catch (_) {
        // The staged file remains available for another attempt on next launch.
      }
    });
    return _queue;
  }

  void dispose() => _channel.setMethodCallHandler(null);
}
