import 'dart:async';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_readium/flutter_readium.dart';

import '../../../core/settings/app_settings.dart';
import '../data/freewise_exporter.dart';
import '../data/freewise_sync.dart';
import '../data/reader_bookmark.dart';
import '../data/readium_storage.dart';

enum _ReaderMenuAction { goToProgress, exportAnnotations, syncAnnotations }

class ReaderPage extends StatefulWidget {
  const ReaderPage({required this.book, required this.settings, super.key});

  final EpubBook book;
  final AppSettings settings;

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
  Locator? _currentLocator;
  List<ReaderDecoration> _decorations = [];
  List<ReaderBookmark> _bookmarks = [];
  TextSelectionEvent? _selectedTextEvent;
  StreamSubscription<Locator>? _locatorSubscription;
  String? _error;
  bool _isLoading = true;
  bool _isSavingHighlight = false;
  bool _isSearching = false;
  bool _isFullscreen = false;
  double _readingProgress = 0;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_applyReaderPreferences);
    _readium.setDefaultPreferences(widget.settings.epubPreferences);
    _openPublication();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_applyReaderPreferences);
    _locatorSubscription?.cancel();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _readium.closePublication();
    super.dispose();
  }

  Future<void> _toggleFullscreen() async {
    final enteringFullscreen = !_isFullscreen;
    await SystemChrome.setEnabledSystemUIMode(
      enteringFullscreen
          ? SystemUiMode.immersiveSticky
          : SystemUiMode.edgeToEdge,
    );
    if (!mounted) return;
    setState(() => _isFullscreen = enteringFullscreen);
  }

  void _applyReaderPreferences() {
    final preferences = widget.settings.epubPreferences;
    _readium.setDefaultPreferences(preferences);
    if (_publication == null) return;

    _readium.setEPUBPreferences(preferences).catchError((Object error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron aplicar los ajustes: $error')),
        );
      }
    });
  }

  Future<void> _editAppearance() async {
    var darkMode = widget.settings.darkMode;
    var sepiaMode = widget.settings.sepiaMode;
    var fontScale = widget.settings.fontScale;
    var lineHeight = widget.settings.lineHeight;
    var pageMargins = widget.settings.pageMargins;
    final appearance =
        await showDialog<
          ({
            bool darkMode,
            bool sepiaMode,
            double fontScale,
            double lineHeight,
            double pageMargins,
          })
        >(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Apariencia de lectura'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Modo oscuro'),
                    value: darkMode,
                    onChanged: (value) => setDialogState(() {
                      darkMode = value;
                      if (value) sepiaMode = false;
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tono sepia'),
                    value: sepiaMode,
                    onChanged: (value) => setDialogState(() {
                      sepiaMode = value;
                      if (value) darkMode = false;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text('Tamaño de letra · ${(fontScale * 100).round()}%'),
                  Slider(
                    value: fontScale,
                    min: 0.8,
                    max: 1.8,
                    divisions: 10,
                    label: '${(fontScale * 100).round()}%',
                    onChanged: (value) =>
                        setDialogState(() => fontScale = value),
                  ),
                  Text('Interlineado · ${lineHeight.toStringAsFixed(1)}'),
                  Slider(
                    value: lineHeight,
                    min: 1,
                    max: 2,
                    divisions: 10,
                    label: lineHeight.toStringAsFixed(1),
                    onChanged: (value) =>
                        setDialogState(() => lineHeight = value),
                  ),
                  Text('Márgenes · ${(pageMargins * 100).round()}%'),
                  Slider(
                    value: pageMargins,
                    min: 0.5,
                    max: 2,
                    divisions: 15,
                    label: '${(pageMargins * 100).round()}%',
                    onChanged: (value) =>
                        setDialogState(() => pageMargins = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, (
                    darkMode: darkMode,
                    sepiaMode: sepiaMode,
                    fontScale: fontScale,
                    lineHeight: lineHeight,
                    pageMargins: pageMargins,
                  )),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ),
        );
    if (appearance == null) return;

    await widget.settings.updateAppearance(
      darkMode: appearance.darkMode,
      sepiaMode: appearance.sepiaMode,
      fontScale: appearance.fontScale,
      lineHeight: appearance.lineHeight,
      pageMargins: appearance.pageMargins,
    );
  }

  Future<void> _openTableOfContents() async {
    final publication = _publication;
    if (publication == null) return;
    final links = _flattenContents(publication.tableOfContents).toList();
    if (links.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este EPUB no incluye un índice.')),
      );
      return;
    }

    final selectedLink = await showModalBottomSheet<Link>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Índice del libro',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar índice',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: links.length,
                  itemBuilder: (context, index) {
                    final (link, depth) = links[index];
                    final label = link.title?.trim().isNotEmpty == true
                        ? link.title!.trim()
                        : Uri.decodeComponent(
                            link.href.split('#').first.split('/').last,
                          );
                    return ListTile(
                      contentPadding: EdgeInsetsDirectional.only(
                        start: 20 + depth * 20,
                        end: 16,
                      ),
                      title: Text(label),
                      onTap: () => Navigator.pop(sheetContext, link),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selectedLink == null) return;

    final locator = publication.locatorFromLink(selectedLink);
    if (locator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir esa sección.')),
      );
      return;
    }
    final navigated = await _readium.goToLocator(locator);
    if (mounted && !navigated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir esa sección.')),
      );
    }
  }

  Future<void> _searchInBook() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buscar en el libro'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(labelText: 'Palabra o frase'),
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || query == null) return;
    final searchKey = query.trim();
    if (searchKey.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final results = await _readium.searchInPublication(searchKey);
      if (!mounted) return;
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay resultados para «$searchKey».')),
        );
        return;
      }
      await _showSearchResults(searchKey, results);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo buscar en el EPUB: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _showSearchResults(
    String query,
    List<TextSearchResult> results,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resultados de búsqueda',
                            style: Theme.of(sheetContext).textTheme.titleLarge,
                          ),
                          Text('«$query» · ${results.length} resultados'),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar resultados',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final chapter =
                        result.chapterTitle?.trim().isNotEmpty == true
                        ? result.chapterTitle!.trim()
                        : result.locator.title?.trim().isNotEmpty == true
                        ? result.locator.title!.trim()
                        : 'Capítulo';
                    final text = result.locator.text;
                    final excerpt = [text?.before, text?.highlight, text?.after]
                        .whereType<String>()
                        .where((part) => part.isNotEmpty)
                        .join(' ');
                    return ListTile(
                      leading: const Icon(Icons.search),
                      title: Text(chapter),
                      subtitle: Text(
                        excerpt.isEmpty ? result.locator.href : excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _goToSearchResult(result);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goToSearchResult(TextSearchResult result) async {
    final navigated = await _readium.goToLocator(result.locator);
    if (mounted && !navigated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir ese resultado.')),
      );
    }
  }

  Future<void> _openProgressNavigator() async {
    var selectedProgress = _readingProgress.clamp(0.0, 1.0).toDouble();
    final progress = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ir a una posición'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Progreso del libro: ${(selectedProgress * 100).round()}%'),
              Slider(
                value: selectedProgress,
                min: 0,
                max: 1,
                divisions: 100,
                label: '${(selectedProgress * 100).round()}%',
                onChanged: (value) =>
                    setDialogState(() => selectedProgress = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedProgress),
              child: const Text('Ir'),
            ),
          ],
        ),
      ),
    );
    if (progress == null || !mounted) return;

    try {
      final navigated = await _readium.goToProgression(progress);
      if (!mounted) return;
      if (!navigated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo ir a esa posición.')),
        );
        return;
      }
      setState(() => _readingProgress = progress);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar de posición: $error')),
      );
    }
  }

  void _handleMenuAction(_ReaderMenuAction action) {
    switch (action) {
      case _ReaderMenuAction.goToProgress:
        _openProgressNavigator();
      case _ReaderMenuAction.exportAnnotations:
        _exportAnnotations();
      case _ReaderMenuAction.syncAnnotations:
        _syncAnnotations();
    }
  }

  Iterable<(Link, int)> _flattenContents(
    List<Link> links, [
    int depth = 0,
  ]) sync* {
    for (final link in links) {
      yield (link, depth);
      yield* _flattenContents(link.children, depth + 1);
    }
  }

  Future<void> _addBookmark() async {
    final locator = _currentLocator ?? _initialLocator;
    if (locator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aún no se conoce la posición actual.')),
      );
      return;
    }

    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Añadir marcador'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre (opcional)',
            hintText: 'Por ejemplo, “Capítulo favorito”',
          ),
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || label == null) return;

    final updated = [
      ..._bookmarks,
      ReaderBookmark.create(locator: locator, label: label),
    ];
    try {
      await _storage.saveBookmarks(widget.book.id, updated);
      if (!mounted) return;
      setState(() => _bookmarks = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marcador guardado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el marcador: $error')),
      );
    }
  }

  Future<void> _openBookmarks() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var bookmarks = List<ReaderBookmark>.of(_bookmarks);
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Marcadores',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Añadir marcador aquí',
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _addBookmark();
                          },
                          icon: const Icon(Icons.bookmark_add_outlined),
                        ),
                        IconButton(
                          tooltip: 'Cerrar marcadores',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (bookmarks.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('Todavía no has guardado marcadores.'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: bookmarks.length,
                        itemBuilder: (context, index) {
                          final bookmark = bookmarks[index];
                          final title = bookmark.label.isNotEmpty
                              ? bookmark.label
                              : bookmark.locator.title?.trim().isNotEmpty ==
                                    true
                              ? bookmark.locator.title!.trim()
                              : 'Punto ${index + 1}';
                          final progression =
                              bookmark.locator.locations?.progression;
                          final subtitle = progression == null
                              ? bookmark.locator.href
                              : '${(progression * 100).round()}% del capítulo';
                          return ListTile(
                            leading: const Icon(Icons.bookmark_outline),
                            title: Text(title),
                            subtitle: Text(subtitle),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _goToBookmark(bookmark);
                            },
                            trailing: IconButton(
                              tooltip: 'Eliminar marcador',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(
                                  this.context,
                                );
                                final updated = bookmarks
                                    .where((item) => item.id != bookmark.id)
                                    .toList();
                                try {
                                  await _storage.saveBookmarks(
                                    widget.book.id,
                                    updated,
                                  );
                                  if (!mounted) return;
                                  setState(() => _bookmarks = updated);
                                  setSheetState(() => bookmarks = updated);
                                } catch (error) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'No se pudo eliminar el marcador: $error',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _goToBookmark(ReaderBookmark bookmark) async {
    final navigated = await _readium.goToLocator(bookmark.locator);
    if (mounted && !navigated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir ese marcador.')),
      );
    }
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
      _readium.setDefaultPreferences(widget.settings.epubPreferences);
      final publication = await _readium.openPublication(path);
      final locator = await _storage.loadLocator(widget.book.id);
      final decorations = await _storage.loadDecorations(widget.book.id);
      final bookmarks = await _storage.loadBookmarks(widget.book.id);
      if (!mounted) return;
      final currentLocator =
          locator ??
          (publication.readingOrder.isEmpty
              ? null
              : publication.locatorFromLink(publication.readingOrder.first));

      setState(() {
        _publication = publication;
        _initialLocator = locator;
        _currentLocator = currentLocator;
        _readingProgress = currentLocator?.locations?.totalProgression ?? 0;
        _decorations = decorations;
        _bookmarks = bookmarks;
        _isLoading = false;
      });

      _locatorSubscription = _readium.onTextLocatorChanged.listen((locator) {
        _currentLocator = locator;
        final progression = locator.locations?.totalProgression;
        if (progression != null && mounted) {
          setState(() => _readingProgress = progression.clamp(0.0, 1.0));
        }
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

  Future<void> _saveHighlight(Locator locator, String? selectedText) async {
    final text = selectedText ?? locator.text?.highlight ?? '';
    if (text.trim().isEmpty || _isSavingHighlight) return;

    setState(() => _isSavingHighlight = true);

    final decoration = ReaderDecoration(
      id: 'highlight_${DateTime.now().microsecondsSinceEpoch}',
      locator: locator,
      style: const ReaderDecorationStyle(
        style: DecorationStyle.highlight,
        tint: Color(0x80FFF176),
      ),
    );
    final decorations = [..._decorations, decoration];
    try {
      await _storage.saveDecorations(widget.book.id, decorations);
      await _readium.applyDecorations('edureader', decorations);
      await HighlightService.saveHighlight(
        Highlight.create(
          bookId: widget.book.id,
          chapterIndex: _chapterIndex(locator),
          text: text,
          color: const Color(0xFFFDD835),
        ),
      );
      if (!mounted) return;
      setState(() {
        _decorations = decorations;
        _selectedTextEvent = null;
        _isSavingHighlight = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subrayado guardado.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingHighlight = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el subrayado: $error')),
      );
    }
  }

  Future<void> _saveCurrentSelection() async {
    final selection = _selectedTextEvent;
    if (selection != null) {
      await _saveHighlight(selection.locator, selection.selectedText);
    }
  }

  Future<void> _applyHighlight(SelectionActionEvent event) {
    return _saveHighlight(event.locator, event.selectedText);
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

  void _rememberSelection(TextSelectionEvent event) {
    if (!mounted) return;
    setState(() => _selectedTextEvent = event);
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
    try {
      final baseUrl = await _sync.getBaseUrl();
      if (baseUrl == null || baseUrl.isEmpty) return;

      final count = await _sync.syncBook(widget.book);
      if (!mounted || count == 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nuevas anotaciones sincronizadas.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo sincronizar automáticamente: $error'),
        ),
      );
    }
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
      appBar: _isFullscreen
          ? null
          : AppBar(
              toolbarHeight: 44,
              titleSpacing: 4,
              title: Text(widget.book.metadata.title),
              actions: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 21,
                  onPressed: _toggleFullscreen,
                  tooltip: 'Pantalla completa',
                  icon: const Icon(Icons.fullscreen),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 21,
                  onPressed: _openTableOfContents,
                  tooltip: 'Índice del libro',
                  icon: const Icon(Icons.menu_book_outlined),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 21,
                  onPressed: _openBookmarks,
                  tooltip: 'Marcadores',
                  icon: const Icon(Icons.bookmarks_outlined),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 21,
                  onPressed: _editAppearance,
                  tooltip: 'Apariencia de lectura',
                  icon: const Icon(Icons.text_fields),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 21,
                  onPressed: _isSearching ? null : _searchInBook,
                  tooltip: 'Buscar en el libro',
                  icon: _isSearching
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
                PopupMenuButton<_ReaderMenuAction>(
                  tooltip: 'Más opciones',
                  onSelected: _handleMenuAction,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _ReaderMenuAction.goToProgress,
                      child: Row(
                        children: [
                          Icon(Icons.linear_scale),
                          SizedBox(width: 12),
                          Text('Ir a una posición'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _ReaderMenuAction.exportAnnotations,
                      child: Row(
                        children: [
                          Icon(Icons.ios_share_outlined),
                          SizedBox(width: 12),
                          Text('Exportar anotaciones'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _ReaderMenuAction.syncAnnotations,
                      child: Row(
                        children: [
                          Icon(Icons.cloud_upload_outlined),
                          SizedBox(width: 12),
                          Text('Sincronizar con FreeWise'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: _isFullscreen
          ? Stack(
              children: [
                Positioned.fill(child: _buildBody()),
                Positioned(
                  top: 8,
                  right: 8,
                  child: SafeArea(
                    child: Material(
                      elevation: 3,
                      color: Theme.of(context).colorScheme.surface,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: _toggleFullscreen,
                        tooltip: 'Salir de pantalla completa',
                        icon: const Icon(Icons.fullscreen_exit),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _buildBody(),
      floatingActionButton: _selectedTextEvent == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isSavingHighlight ? null : _saveCurrentSelection,
              icon: _isSavingHighlight
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.highlight_alt_outlined),
              label: Text(_isSavingHighlight ? 'Guardando…' : 'Subrayar'),
            ),
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
      onTextSelected: _rememberSelection,
      onSelectionAction: _handleSelectionAction,
    );
  }
}
