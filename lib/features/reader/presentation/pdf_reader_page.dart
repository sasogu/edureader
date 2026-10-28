import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';

import '../../library/data/pdf_storage.dart';
import '../data/readium_storage.dart';
import '../../../l10n/app_localizations.dart';

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({required this.document, super.key});

  final PdfDocument document;

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  final FlutterReadium _readium = FlutterReadium();
  final ReadiumStorage _storage = ReadiumStorage();
  Publication? _publication;
  Locator? _initialLocator;
  StreamSubscription<Locator>? _locatorSubscription;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final publication = await _readium.openPublication(widget.document.path);
      final locator = await _storage.loadLocator(widget.document.id);
      if (!mounted) return;
      setState(() {
        _publication = publication;
        _initialLocator = locator;
      });
      _locatorSubscription = _readium.onTextLocatorChanged.listen((location) {
        unawaited(_storage.saveLocator(widget.document.id, location));
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _locatorSubscription?.cancel();
    unawaited(_readium.closePublication());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.document.title)),
    body: _error != null
        ? Center(child: Text(AppLocalizations.of(context).readerError(_error!)))
        : _publication == null
        ? const Center(child: CircularProgressIndicator())
        : ReadiumReaderWidget(
            publication: _publication!,
            initialLocator: _initialLocator,
          ),
  );
}
