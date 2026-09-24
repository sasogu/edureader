import 'dart:async';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_readium/flutter_readium.dart';

import '../data/freewise_exporter.dart';
import '../data/freewise_sync.dart';
import '../data/readium_storage.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({required this.book, super.key});

  final EpubBook book;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final FlutterReadium _readium = FlutterReadium();
  final ReadiumStorage _storage = ReadiumStorage();
  final FreeWiseExporter _exporter = FreeWiseExporter();
  final FreeWiseSync _sync = FreeWiseSync();

  Publication? _publication;
  Locator? _initialLocator;
  List<ReaderDecoration> _decorations = [];
  StreamSubscription<Locator>? _locatorSubscription;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _openPublication();
  }

  @override
  void dispose() {
    _locatorSubscription?.cancel();
    _readium.closePublication();
    super.dispose();
  }

  Future<void> _openPublication() async {
    final path = widget.book.filePath;
    if (path == null || path.isEmpty) {
      setState(() {
        _error = 'El EPUB no tiene una ruta local disponible.';
        _isLoading = false;
      });
      return;
    }

    try {
      _readium.setDefaultPreferences(const EPUBPreferences(scroll: false));
      final publication = await _readium.openPublication(path);
      final locator = await _storage.loadLocator(widget.book.id);
      final decorations = await _storage.loadDecorations(widget.book.id);
      if (!mounted) return;

      setState(() {
        _publication = publication;
        _initialLocator = locator;
        _decorations = decorations;
        _isLoading = false;
      });

      _locatorSubscription = _readium.onTextLocatorChanged.listen((locator) {
        _storage.saveLocator(widget.book.id, locator);
      });
      if (decorations.isNotEmpty) {
        await _readium.applyDecorations('edureader', decorations);
      }
      _syncIfConfigured();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se ha podido abrir el EPUB con Readium: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _applyHighlight(SelectionActionEvent event) async {
    final text = event.selectedText ?? event.locator.text?.highlight ?? '';
    if (text.trim().isEmpty) return;

    final decoration = ReaderDecoration(
      id: 'highlight_${DateTime.now().microsecondsSinceEpoch}',
      locator: event.locator,
      style: const ReaderDecorationStyle(
        style: DecorationStyle.highlight,
        tint: Color(0x80FFF176),
      ),
    );
    _decorations = [..._decorations, decoration];
    await _storage.saveDecorations(widget.book.id, _decorations);
    await _readium.applyDecorations('edureader', _decorations);

    await HighlightService.saveHighlight(
      Highlight.create(
        bookId: widget.book.id,
        chapterIndex: _chapterIndex(event.locator),
        text: text,
        color: const Color(0xFFFDD835),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subrayado guardado.')));
    }
  }

  Future<void> _applyNote(SelectionActionEvent event) async {
    final text = event.selectedText ?? event.locator.text?.highlight ?? '';
    if (text.trim().isEmpty || !mounted) return;

    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir nota'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Escribe una nota'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || note.trim().isEmpty) return;

    await NoteService.saveNote(
      Note.create(
        bookId: widget.book.id,
        chapterIndex: _chapterIndex(event.locator),
        selectedText: text,
        content: note.trim(),
      ),
    );
  }

  Future<void> _handleSelectionAction(SelectionActionEvent event) async {
    switch (event.actionId) {
      case 'copy':
        final text = event.selectedText ?? event.locator.text?.highlight ?? '';
        await Clipboard.setData(ClipboardData(text: text));
      case 'highlight':
        await _applyHighlight(event);
      case 'note':
        await _applyNote(event);
    }
  }

  int _chapterIndex(Locator locator) {
    final index = widget.book.chapters.indexWhere(
      (chapter) =>
          locator.href.endsWith(chapter.filePath) ||
          chapter.filePath.endsWith(locator.href),
    );
    return index < 0 ? 0 : index;
  }

  Future<void> _exportAnnotations() async {
    final count = await _exporter.exportBook(widget.book);
    if (!mounted || count == null || count == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count anotaciones exportadas a CSV.')),
    );
  }

  Future<void> _syncIfConfigured() async {
    final baseUrl = await _sync.getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) return;
    try {
      final count = await _sync.syncBook(widget.book);
      if (!mounted || count == 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nuevas anotaciones sincronizadas.')),
      );
    } catch (_) {}
  }

  Future<void> _syncAnnotations() async {
    var baseUrl = await _sync.getBaseUrl();
    if (!mounted) return;
    if (baseUrl == null || baseUrl.isEmpty) {
      final controller = TextEditingController(
        text: 'http://freewise.example.com',
      );
      final configuredUrl = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Configurar FreeWise'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'URL del servidor'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Guardar y sincronizar'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (!mounted || configuredUrl == null || configuredUrl.trim().isEmpty) {
        return;
      }
      await _sync.setBaseUrl(configuredUrl);
      baseUrl = configuredUrl;
    }

    try {
      final count = await _sync.syncBook(widget.book);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'No hay anotaciones nuevas para sincronizar.'
                : 'Anotaciones enviadas a FreeWise.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo sincronizar con FreeWise: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.metadata.title),
        actions: [
          IconButton(
            onPressed: _exportAnnotations,
            tooltip: 'Exportar a FreeWise',
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            onPressed: _syncAnnotations,
            tooltip: 'Sincronizar con FreeWise',
            icon: const Icon(Icons.cloud_upload_outlined),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    final publication = _publication;
    if (publication == null) return const SizedBox.shrink();
    return ReadiumReaderWidget(
      publication: publication,
      initialLocator: _initialLocator,
      allowedDefaultActions: const {
        DefaultSelectionAction.copy,
        DefaultSelectionAction.share,
      },
      selectionActions: const [
        SelectionAction(id: 'copy', title: 'Copiar'),
        SelectionAction(id: 'highlight', title: 'Subrayar'),
        SelectionAction(id: 'note', title: 'Nota'),
      ],
      onSelectionAction: _handleSelectionAction,
    );
  }
}
