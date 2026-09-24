import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:flutter/material.dart';

import '../data/freewise_exporter.dart';
import '../data/freewise_sync.dart';
import '../data/reading_progress_storage.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({required this.book, super.key});

  final EpubBook book;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final ReadingProgressStorage _progressStorage = ReadingProgressStorage();
  final FreeWiseExporter _exporter = FreeWiseExporter();
  final FreeWiseSync _sync = FreeWiseSync();
  ReadingProgress? _progress;
  bool _isLoadingProgress = true;
  String? _selectedText;
  int _currentChapterIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _syncIfConfigured();
  }

  Future<void> _loadProgress() async {
    final progress = await _progressStorage.load(widget.book.id);
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _isLoadingProgress = false;
    });
  }

  void _saveProgress(ReadingProgress progress) {
    _progressStorage.save(progress);
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
    } catch (_) {
      // La sincronización automática es silenciosa; el botón permite reintentar.
    }
  }

  void _saveNote({
    required int chapterIndex,
    required double position,
    required String selectedText,
    required String noteContent,
    String? color,
  }) {
    NoteService.saveNote(
      Note.create(
        bookId: widget.book.id,
        chapterIndex: chapterIndex,
        selectedText: selectedText,
        content: noteContent,
      ),
    );
  }

  Future<void> _saveSelectedHighlight() async {
    final text = _selectedText;
    if (text == null || text.trim().isEmpty) return;

    await HighlightService.saveHighlight(
      Highlight.create(
        bookId: widget.book.id,
        chapterIndex: _currentChapterIndex,
        text: text,
        color: const Color(0xFFFDD835),
      ),
    );
    if (!mounted) return;
    setState(() => _selectedText = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Subrayado guardado.')));
  }

  void _handleTextSelected(String text) {
    if (text.trim().isEmpty) return;
    setState(() => _selectedText = text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Texto seleccionado'),
        action: SnackBarAction(
          label: 'SUBRAYAR',
          onPressed: _saveSelectedHighlight,
        ),
      ),
    );
  }

  Future<void> _exportAnnotations() async {
    final count = await _exporter.exportBook(widget.book);
    if (!mounted || count == null || count == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count anotaciones exportadas a CSV.')),
    );
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
            decoration: const InputDecoration(
              labelText: 'URL del servidor',
              hintText: 'http://freewise.example.com',
            ),
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
    final progress = _progress;
    if (_isLoadingProgress) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.metadata.title),
        actions: [
          IconButton(
            onPressed: _selectedText == null ? null : _saveSelectedHighlight,
            tooltip: 'Subrayar selección',
            icon: const Icon(Icons.highlight_outlined),
          ),
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
      body: EpubViewer(
        book: widget.book,
        initialChapterIndex: progress?.currentChapterIndex ?? 0,
        initialPosition: progress?.chapterProgress ?? 0,
        showControls: true,
        showTableOfContents: true,
        onProgressChanged: _saveProgress,
        onNoteSaved: _saveNote,
        onTextSelected: _handleTextSelected,
        onChapterChanged: (chapterIndex) {
          _currentChapterIndex = chapterIndex;
        },
      ),
    );
  }
}
