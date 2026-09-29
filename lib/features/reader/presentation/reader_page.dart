import 'dart:async';

import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_readium/flutter_readium.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/completed_dialog.dart';
import '../data/freewise_exporter.dart';
import '../data/freewise_sync.dart';
import '../data/reader_bookmark.dart';
import '../data/readium_storage.dart';
import 'highlight_color_dialog.dart';
import 'read_aloud_mini_player.dart';

enum _ReaderMenuAction {
  readAloud,
  goToProgress,
  exportAnnotations,
  syncAnnotations,
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    required this.book,
    required this.settings,
    this.onAppBackground,
    super.key,
  });

  final EpubBook book;
  final AppSettings settings;

  /// Se llama cuando la app pasa a segundo plano con el libro abierto, después
  /// de guardar la posición actual.
  final Future<void> Function()? onAppBackground;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
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
  Future<void> _locatorSaveQueue = Future<void>.value();
  String? _error;
  bool _isLoading = true;
  bool _isSavingHighlight = false;
  bool _isChoosingHighlight = false;
  bool _isSearching = false;
  bool _isFullscreen = false;
  bool _isReaderMenuOpen = false;
  bool _ttsEnabled = false;
  bool _isTtsPlaying = false;
  bool _isTtsBusy = false;
  bool _miniPlayerAtTop = false;
  StreamSubscription<ReadiumTimebasedState>? _ttsSubscription;
  double _ttsSpeed = 1;
  double _readingProgress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_applyReaderPreferences);
    _readium.setDefaultPreferences(widget.settings.epubPreferences);
    _ttsSubscription = _readium.onTimebasedPlayerStateChanged.listen(
      _handleTimebasedState,
      onError: (Object _) {},
    );
    _openPublication();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_applyReaderPreferences);
    _locatorSubscription?.cancel();
    _ttsSubscription?.cancel();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _readium.closePublication();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `hidden` llega antes que `paused` en iOS y Android: deja más margen
    // para enviar la posición antes de que el sistema suspenda la app.
    if (state == AppLifecycleState.hidden) {
      unawaited(_saveAndNotifyBackground());
    }
  }

  Future<void> _saveAndNotifyBackground() async {
    try {
      await _persistCurrentLocator();
    } catch (_) {
      // Se sincroniza lo último que se llegó a guardar.
    }
    await widget.onAppBackground?.call();
  }

  Future<void> _toggleFullscreen() async {
    final enteringFullscreen = !_isFullscreen;
    try {
      await _persistCurrentLocator();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar la posición actual: $error'),
          ),
        );
      }
    }
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
    var justifyText = widget.settings.justifyText;
    final appearance =
        await showDialog<
          ({
            bool darkMode,
            bool sepiaMode,
            double fontScale,
            double lineHeight,
            double pageMargins,
            bool justifyText,
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Justificar texto'),
                    subtitle: const Text(
                      'Alinea el texto a ambos márgenes cuando el EPUB lo permita.',
                    ),
                    value: justifyText,
                    onChanged: (value) =>
                        setDialogState(() => justifyText = value),
                  ),
                  const SizedBox(height: 8),
                  Text('Tamaño de letra · ${(fontScale * 100).round()}%'),
                  Slider(
                    value: fontScale,
                    min: 0.8,
                    max: 2.5,
                    divisions: 17,
                    label: '${(fontScale * 100).round()}%',
                    semanticFormatterCallback: (value) =>
                        'Tamaño de letra: ${(value * 100).round()} por ciento',
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
                    semanticFormatterCallback: (value) =>
                        'Interlineado: ${value.toStringAsFixed(1)}',
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
                    semanticFormatterCallback: (value) =>
                        'Márgenes: ${(value * 100).round()} por ciento',
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
                    justifyText: justifyText,
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
      justifyText: appearance.justifyText,
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
    final query = await showCompletedDialog<String>(
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.titleLarge,
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
                        final excerpt =
                            [text?.before, text?.highlight, text?.after]
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
                semanticFormatterCallback: (value) =>
                    'Progreso del libro: ${(value * 100).round()} por ciento',
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

  Future<void> _toggleTtsPlayback() async {
    if (_isTtsBusy) return;
    setState(() => _isTtsBusy = true);
    try {
      final wasPlaying = _isTtsPlaying;
      if (wasPlaying) {
        await _readium.pause();
      } else if (_ttsEnabled) {
        await _readium.resume();
      } else {
        await _readium.ttsEnable(
          TTSPreferences(speed: ttsEngineRate(_ttsSpeed)),
        );
        await _readium.play(null);
      }
      if (mounted) {
        setState(() {
          _ttsEnabled = true;
          _isTtsPlaying = !wasPlaying;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo iniciar la lectura en voz alta: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTtsBusy = false);
    }
  }

  Future<void> _skipTts(bool forward) async {
    try {
      if (forward) {
        await _readium.next();
      } else {
        await _readium.previous();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo avanzar en la lectura: $error')),
        );
      }
    }
  }

  Future<void> _updateTtsSpeed(double speed) async {
    setState(() => _ttsSpeed = speed);
    if (!_ttsEnabled) return;
    try {
      await _readium.ttsSetPreferences(
        TTSPreferences(speed: ttsEngineRate(speed)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cambiar la velocidad: $error')),
        );
      }
    }
  }

  Future<void> _startReadAloud() async {
    if (_ttsEnabled) return;
    await _toggleTtsPlayback();
  }

  Future<void> _closeReadAloud() async {
    setState(() {
      _ttsEnabled = false;
      _isTtsPlaying = false;
    });
    try {
      await _readium.stop();
    } catch (_) {
      // Si ya estaba parado no hay nada que cerrar.
    }
  }

  /// Mantiene el botón de reproducir al día cuando la lectura se pausa desde
  /// la notificación, la pantalla de bloqueo o al terminar el libro.
  void _handleTimebasedState(ReadiumTimebasedState state) {
    if (!mounted || !_ttsEnabled) return;
    final playing =
        state.state == TimebasedState.playing ||
        state.state == TimebasedState.loading;
    if (playing != _isTtsPlaying) setState(() => _isTtsPlaying = playing);
  }

  void _handleMenuAction(_ReaderMenuAction action) {
    switch (action) {
      case _ReaderMenuAction.goToProgress:
        _openProgressNavigator();
      case _ReaderMenuAction.readAloud:
        _startReadAloud();
      case _ReaderMenuAction.exportAnnotations:
        _exportAnnotations();
      case _ReaderMenuAction.syncAnnotations:
        _syncAnnotations();
    }
  }

  Future<void> _openReaderMenu() async {
    if (_isReaderMenuOpen) return;
    setState(() => _isReaderMenuOpen = true);
    try {
      final action = await showModalBottomSheet<_ReaderMenuAction>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Más opciones'),
              trailing: IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(sheetContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_outlined),
              title: const Text('Lectura en voz alta'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_ReaderMenuAction.readAloud),
            ),
            ListTile(
              leading: const Icon(Icons.linear_scale),
              title: const Text('Ir a una posición'),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_ReaderMenuAction.goToProgress),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('Exportar anotaciones'),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_ReaderMenuAction.exportAnnotations),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Sincronizar con FreeWise'),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_ReaderMenuAction.syncAnnotations),
            ),
          ],
        ),
      );
      if (action != null && mounted) _handleMenuAction(action);
    } finally {
      if (mounted) setState(() => _isReaderMenuOpen = false);
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
    final label = await showCompletedDialog<String>(
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
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
        // Use a bottom border instead of a filled rectangle so the EPUB text
        // remains readable with either light or dark reader colors.
        _decorations = decorations
            .map(
              (decoration) => decoration.copyWith(
                style: decoration.style.copyWith(
                  style: DecorationStyle.underline,
                ),
              ),
            )
            .toList();
        _bookmarks = bookmarks;
        _isLoading = false;
      });

      _locatorSubscription = _readium.onTextLocatorChanged.listen((locator) {
        _currentLocator = locator;
        _initialLocator = locator;
        _queueLocatorSave(locator);
        final progression = locator.locations?.totalProgression;
        if (progression != null && mounted) {
          setState(() => _readingProgress = progression.clamp(0.0, 1.0));
        }
      });
      _syncIfConfigured();
      if (decorations.any((d) => d.style.style != DecorationStyle.underline)) {
        await _storage.saveDecorations(widget.book.id, _decorations);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se ha podido abrir el EPUB con Readium: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreDecorations() async {
    if (!mounted || _decorations.isEmpty) return;
    try {
      await _readium.applyDecorations('edureader', _decorations);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron mostrar los subrayados guardados.'),
        ),
      );
    }
  }

  void _queueLocatorSave(Locator locator) {
    _locatorSaveQueue = _locatorSaveQueue
        .catchError((Object _) {})
        .then((_) => _storage.saveLocator(widget.book.id, locator));
  }

  Future<void> _persistCurrentLocator() async {
    final locator = _currentLocator;
    if (locator != null) {
      _queueLocatorSave(locator);
      await _locatorSaveQueue;
      _initialLocator = locator;
    } else {
      await _locatorSaveQueue;
    }
  }

  Future<void> _chooseHighlight(Locator locator, String? selectedText) async {
    if (!mounted || _isChoosingHighlight || _isSavingHighlight) return;
    if ((selectedText ?? locator.text?.highlight ?? '').trim().isEmpty) return;
    setState(() => _isChoosingHighlight = true);
    try {
      final color = await showCompletedDialog<Color>(
        context: context,
        builder: (_) =>
            HighlightColorDialog(initialColor: widget.settings.highlightColor),
      );
      if (!mounted || color == null) return;
      await widget.settings.setHighlightColor(color);
      if (!mounted) return;
      await _saveHighlight(locator, selectedText, color);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el color del subrayado.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChoosingHighlight = false);
    }
  }

  Future<void> _saveHighlight(
    Locator locator,
    String? selectedText,
    Color color,
  ) async {
    final text = selectedText ?? locator.text?.highlight ?? '';
    if (text.trim().isEmpty || _isSavingHighlight) return;

    setState(() => _isSavingHighlight = true);

    final highlight = Highlight.create(
      bookId: widget.book.id,
      chapterIndex: _chapterIndex(locator),
      text: text,
      color: color,
    );
    final decoration = ReaderDecoration(
      id: 'highlight_${highlight.id}',
      locator: locator,
      style: ReaderDecorationStyle(
        style: DecorationStyle.underline,
        tint: color,
      ),
    );
    final decorations = [..._decorations, decoration];
    try {
      await _storage.saveDecorations(widget.book.id, decorations);
      await _readium.applyDecorations('edureader', decorations);
      await HighlightService.saveHighlight(highlight);
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
      await _chooseHighlight(selection.locator, selection.selectedText);
    }
  }

  Future<void> _removeDecoration(DecorationInteractionEvent event) async {
    final matchingDecorations = _decorations.where(
      (item) => item.id == event.decorationId,
    );
    final decoration = matchingDecorations.isEmpty
        ? null
        : matchingDecorations.first;
    if (decoration == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar subrayado'),
        content: Text(
          decoration.locator.text?.highlight ?? '¿Eliminar este subrayado?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    final remaining = _decorations
        .where((item) => item.id != event.decorationId)
        .toList();
    await _storage.saveDecorations(widget.book.id, remaining);
    await _readium.applyDecorations('edureader', remaining);
    final highlightId = event.decorationId.startsWith('highlight_')
        ? event.decorationId.substring('highlight_'.length)
        : null;
    if (highlightId != null) {
      await HighlightService.deleteHighlight(highlightId);
    } else {
      // Older saved decorations did not share an ID with their exported
      // highlight record, so remove the matching legacy record by its text.
      final text = decoration.locator.text?.highlight;
      if (text != null) {
        final highlights = await HighlightService.getHighlights(widget.book.id);
        final legacyMatch = highlights.where(
          (item) =>
              item.text == text &&
              item.chapterIndex == _chapterIndex(decoration.locator),
        );
        if (legacyMatch.isNotEmpty) {
          await HighlightService.deleteHighlight(legacyMatch.first.id);
        }
      }
    }
    if (!mounted) return;
    setState(() => _decorations = remaining);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Subrayado eliminado.')));
  }

  Future<void> _applyHighlight(SelectionActionEvent event) {
    // The system context menu is the quick action: reuse the most recently
    // chosen color without interrupting reading with the color picker.
    return _saveHighlight(
      event.locator,
      event.selectedText,
      widget.settings.highlightColor,
    );
  }

  Future<void> _applyNote(SelectionActionEvent event) async {
    final text = event.selectedText ?? event.locator.text?.highlight ?? '';
    if (text.trim().isEmpty || !mounted) return;

    final controller = TextEditingController();
    final note = await showCompletedDialog<String>(
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
      final controller = TextEditingController();
      final configuredUrl = await showCompletedDialog<String>(
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
    } catch (error, stackTrace) {
      debugPrint('FreeWise sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
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
                IconButton(
                  tooltip: 'Más opciones',
                  onPressed: _openReaderMenu,
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _isReaderMenuOpen || _isChoosingHighlight,
              child: _buildBody(),
            ),
          ),
          if (_ttsEnabled)
            Positioned(
              left: 12,
              right: 12,
              top: _miniPlayerAtTop ? 8 : null,
              // Deja sitio al botón «Subrayar» cuando hay texto seleccionado.
              bottom: _miniPlayerAtTop
                  ? null
                  : (_selectedTextEvent == null ? 12 : 84),
              child: SafeArea(
                top: _miniPlayerAtTop,
                bottom: !_miniPlayerAtTop,
                child: Center(
                  child: ReadAloudMiniPlayer(
                    isPlaying: _isTtsPlaying,
                    isBusy: _isTtsBusy,
                    speed: _ttsSpeed,
                    onTogglePlayback: _toggleTtsPlayback,
                    onSkip: _skipTts,
                    onSpeedChanged: _updateTtsSpeed,
                    onClose: _closeReadAloud,
                    onMove: (up) => setState(() => _miniPlayerAtTop = up),
                  ),
                ),
              ),
            ),
          if (_isFullscreen)
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
      ),
      floatingActionButton: _selectedTextEvent == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isSavingHighlight ? null : _saveCurrentSelection,
              icon: _isSavingHighlight
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: widget.settings.highlightColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: 1.5,
                        ),
                      ),
                    ),
              label: Text(_isSavingHighlight ? 'Guardando…' : 'Elegir color'),
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
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, child) => ColoredBox(
        color: widget.settings.readerBackgroundColor,
        child: SafeArea(
          top: _isFullscreen,
          bottom: _isFullscreen,
          left: false,
          right: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: widget.settings.verticalPageMargin,
            ),
            child: child,
          ),
        ),
      ),
      child: _buildReader(publication),
    );
  }

  Widget _buildReader(Publication publication) {
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
      onReaderReady: _restoreDecorations,
      onTextSelected: _rememberSelection,
      onSelectionAction: _handleSelectionAction,
      onDecorationInteraction: _removeDecoration,
    );
  }
}
