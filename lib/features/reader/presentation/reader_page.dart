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
import '../../../l10n/app_localizations.dart';

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
    this.onBookStateChanged,
    super.key,
  });

  final EpubBook book;
  final AppSettings settings;

  /// Se llama cuando la app pasa a segundo plano con el libro abierto, después
  /// de guardar la posición actual.
  final Future<void> Function()? onAppBackground;
  final Future<void> Function()? onBookStateChanged;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  AppLocalizations get _l10n => AppLocalizations.of(context);

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
    _readium.setDefaultPreferences(_readerPreferences());
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
          SnackBar(content: Text(_l10n.savePositionFailed(error.toString()))),
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
    final preferences = _readerPreferences(
      contentLanguage: _publication?.metadata.languages.firstOrNull,
    );
    _readium.setDefaultPreferences(preferences);
    if (_publication == null) return;

    _readium.setEPUBPreferences(preferences).catchError((Object error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.applyPreferencesFailed(error.toString())),
          ),
        );
      }
    });
  }

  EPUBPreferences _readerPreferences({String? contentLanguage}) {
    final preferences = widget.settings.epubPreferences;
    if (!widget.settings.justifyText) return preferences;
    return preferences.copyWith(
      hyphens: true,
      language: contentLanguage ?? 'es',
    );
  }

  Future<T?> _waitForReaderOverlay<T>(Future<T?> overlay) {
    if (mounted) setState(() => _isReaderMenuOpen = true);
    return overlay.whenComplete(() {
      if (mounted) setState(() => _isReaderMenuOpen = false);
    });
  }

  Future<void> _editAppearance() async {
    var darkMode = widget.settings.darkMode;
    var sepiaMode = widget.settings.sepiaMode;
    var fontScale = widget.settings.fontScale;
    var lineHeight = widget.settings.lineHeight;
    var pageMargins = widget.settings.pageMargins;
    var justifyText = widget.settings.justifyText;
    final appearanceRoute =
        showDialog<
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
              title: Text(_l10n.readerAppearance),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_l10n.darkMode),
                      value: darkMode,
                      onChanged: (value) => setDialogState(() {
                        darkMode = value;
                        if (value) sepiaMode = false;
                      }),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_l10n.sepiaTone),
                      value: sepiaMode,
                      onChanged: (value) => setDialogState(() {
                        sepiaMode = value;
                        if (value) darkMode = false;
                      }),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_l10n.justifyText),
                      subtitle: Text(_l10n.justifyHint),
                      value: justifyText,
                      onChanged: (value) =>
                          setDialogState(() => justifyText = value),
                    ),
                    const SizedBox(height: 8),
                    Text(_l10n.fontSize((fontScale * 100).round())),
                    Slider(
                      value: fontScale,
                      min: 0.8,
                      max: 2.5,
                      divisions: 17,
                      label: '${(fontScale * 100).round()}%',
                      semanticFormatterCallback: (value) =>
                          _l10n.fontSizeSemantics((value * 100).round()),
                      onChanged: (value) =>
                          setDialogState(() => fontScale = value),
                    ),
                    Text(_l10n.lineHeight(lineHeight.toStringAsFixed(1))),
                    Slider(
                      value: lineHeight,
                      min: 1,
                      max: 2,
                      divisions: 10,
                      label: lineHeight.toStringAsFixed(1),
                      semanticFormatterCallback: (value) =>
                          _l10n.lineHeightSemantics(value.toStringAsFixed(1)),
                      onChanged: (value) =>
                          setDialogState(() => lineHeight = value),
                    ),
                    Text(_l10n.margins((pageMargins * 100).round())),
                    Slider(
                      value: pageMargins,
                      min: 0.5,
                      max: 2,
                      divisions: 15,
                      label: '${(pageMargins * 100).round()}%',
                      semanticFormatterCallback: (value) =>
                          _l10n.marginsSemantics((value * 100).round()),
                      onChanged: (value) =>
                          setDialogState(() => pageMargins = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(_l10n.cancel),
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
                  child: Text(_l10n.apply),
                ),
              ],
            ),
          ),
        );
    final appearance = await _waitForReaderOverlay(appearanceRoute);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.tocMissing)));
      return;
    }

    final selectedLinkRoute = showModalBottomSheet<Link>(
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
                            _l10n.readerToc,
                            style: Theme.of(sheetContext).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: _l10n.closeToc,
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
    final selectedLink = await _waitForReaderOverlay(selectedLinkRoute);
    if (!mounted || selectedLink == null) return;

    final locator = publication.locatorFromLink(selectedLink);
    if (locator == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.sectionOpenFailed)));
      return;
    }
    final navigated = await _readium.goToLocator(locator);
    if (mounted && !navigated) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.sectionOpenFailed)));
    }
  }

  Future<void> _searchInBook() async {
    final controller = TextEditingController();
    final queryRoute = showCompletedDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.searchInBook),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(labelText: _l10n.searchTerm),
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            icon: const Icon(Icons.search),
            label: Text(_l10n.search),
          ),
        ],
      ),
    );
    final query = await _waitForReaderOverlay(queryRoute);
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
          SnackBar(content: Text(_l10n.searchNoResults(searchKey))),
        );
        return;
      }
      await _showSearchResults(searchKey, results);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.searchFailed(error.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _showSearchResults(
    String query,
    List<TextSearchResult> results,
  ) async {
    final resultsRoute = showModalBottomSheet<void>(
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
                                _l10n.searchResults,
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.titleLarge,
                              ),
                              Text(
                                _l10n.searchResultsCount(query, results.length),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: _l10n.closeResults,
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
                            : _l10n.chapter;
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
    await _waitForReaderOverlay(resultsRoute);
  }

  Future<void> _goToSearchResult(TextSearchResult result) async {
    final navigated = await _readium.goToLocator(result.locator);
    if (mounted && !navigated) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.searchResultFailed)));
    }
  }

  Future<void> _openProgressNavigator() async {
    var selectedProgress = _readingProgress.clamp(0.0, 1.0).toDouble();
    final progressRoute = showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_l10n.goToPosition),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_l10n.bookProgress((selectedProgress * 100).round())),
              Slider(
                value: selectedProgress,
                min: 0,
                max: 1,
                divisions: 100,
                label: '${(selectedProgress * 100).round()}%',
                semanticFormatterCallback: (value) =>
                    _l10n.bookProgress((value * 100).round()),
                onChanged: (value) =>
                    setDialogState(() => selectedProgress = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedProgress),
              child: Text(_l10n.go),
            ),
          ],
        ),
      ),
    );
    final progress = await _waitForReaderOverlay(progressRoute);
    if (progress == null || !mounted) return;

    try {
      final navigated = await _readium.goToProgression(progress);
      if (!mounted) return;
      if (!navigated) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.progressFailed)));
        return;
      }
      setState(() => _readingProgress = progress);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.progressFailed)));
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
          SnackBar(content: Text(_l10n.readAloudFailed(error.toString()))),
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
          SnackBar(content: Text(_l10n.readAloudSkipFailed(error.toString()))),
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
          SnackBar(content: Text(_l10n.readAloudSpeedFailed(error.toString()))),
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
              title: Text(_l10n.readerMore),
              trailing: IconButton(
                tooltip: _l10n.close,
                onPressed: () => Navigator.of(sheetContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_outlined),
              title: Text(_l10n.readAloud),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_ReaderMenuAction.readAloud),
            ),
            ListTile(
              leading: const Icon(Icons.linear_scale),
              title: Text(_l10n.goToPosition),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_ReaderMenuAction.goToProgress),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: Text(_l10n.exportAnnotations),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_ReaderMenuAction.exportAnnotations),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(_l10n.syncFreewise),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.currentPositionUnknown)));
      return;
    }

    final controller = TextEditingController();
    final label = await showCompletedDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.addBookmark),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: _l10n.bookmarkName,
            hintText: _l10n.bookmarkExample,
          ),
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(_l10n.save),
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
      ).showSnackBar(SnackBar(content: Text(_l10n.bookmarkSaved)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.bookmarkSaveFailed(error.toString()))),
      );
    }
  }

  Future<void> _openBookmarks() async {
    final bookmarksRoute = showModalBottomSheet<void>(
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
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _l10n.readerBookmarksAndHighlights,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              IconButton(
                                tooltip: _l10n.addBookmarkHere,
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  _addBookmark();
                                },
                                icon: const Icon(Icons.bookmark_add_outlined),
                              ),
                              IconButton(
                                tooltip: _l10n.closeBookmarks,
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        TabBar(
                          tabs: [
                            Tab(text: _l10n.readerBookmarks),
                            Tab(text: _l10n.savedHighlightsTab),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              if (bookmarks.isEmpty)
                                Center(child: Text(_l10n.noBookmarks))
                              else
                                ListView.builder(
                                  itemCount: bookmarks.length,
                                  itemBuilder: (context, index) {
                                    final bookmark = bookmarks[index];
                                    final title = bookmark.label.isNotEmpty
                                        ? bookmark.label
                                        : bookmark.locator.title
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                        ? bookmark.locator.title!.trim()
                                        : _l10n.bookmarkPoint(index + 1);
                                    final progression =
                                        bookmark.locator.locations?.progression;
                                    final subtitle = progression == null
                                        ? bookmark.locator.href
                                        : '${(progression * 100).round()}% del capítulo';
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.bookmark_outline,
                                      ),
                                      title: Text(title),
                                      subtitle: Text(subtitle),
                                      onTap: () {
                                        Navigator.pop(sheetContext);
                                        _goToBookmark(bookmark);
                                      },
                                      trailing: IconButton(
                                        tooltip: _l10n.deleteBookmark,
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          final messenger =
                                              ScaffoldMessenger.of(
                                                this.context,
                                              );
                                          final updated = bookmarks
                                              .where(
                                                (item) =>
                                                    item.id != bookmark.id,
                                              )
                                              .toList();
                                          try {
                                            await _storage.saveBookmarks(
                                              widget.book.id,
                                              updated,
                                            );
                                            if (!mounted) return;
                                            setState(
                                              () => _bookmarks = updated,
                                            );
                                            setSheetState(
                                              () => bookmarks = updated,
                                            );
                                          } catch (error) {
                                            if (mounted) {
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    _l10n.bookmarkDeleteFailed(
                                                      error.toString(),
                                                    ),
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
                              if (_decorations.isEmpty)
                                Center(child: Text(_l10n.noSavedHighlights))
                              else
                                ListView.builder(
                                  itemCount: _decorations.length,
                                  itemBuilder: (context, index) {
                                    final decoration = _decorations[index];
                                    final text =
                                        decoration.locator.text?.highlight
                                            ?.trim() ??
                                        '';
                                    final progression = decoration
                                        .locator
                                        .locations
                                        ?.totalProgression;
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.format_underline,
                                      ),
                                      title: Text(
                                        text.isEmpty
                                            ? _l10n.savedHighlightFallback
                                            : text,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        progression == null
                                            ? decoration.locator.href
                                            : '${(progression * 100).round()}%',
                                      ),
                                      onTap: () {
                                        Navigator.pop(sheetContext);
                                        _goToHighlight(decoration);
                                      },
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    await _waitForReaderOverlay(bookmarksRoute);
  }

  Future<void> _goToBookmark(ReaderBookmark bookmark) async {
    final navigated = await _readium.goToLocator(bookmark.locator);
    if (mounted && !navigated) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.bookmarkOpenFailed)));
    }
  }

  Future<void> _goToHighlight(ReaderDecoration decoration) async {
    final navigated = await _readium.goToLocator(decoration.locator);
    if (mounted && !navigated) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.sectionOpenFailed)));
    }
  }

  Future<void> _openPublication() async {
    final path = widget.book.filePath;
    if (path == null || path.isEmpty) {
      setState(() {
        _error = _l10n.readerPathMissing;
        _isLoading = false;
      });
      return;
    }

    try {
      _readium.setDefaultPreferences(_readerPreferences());
      final publication = await _readium.openPublication(path);
      await _readium.setEPUBPreferences(
        _readerPreferences(
          contentLanguage: publication.metadata.languages.firstOrNull,
        ),
      );
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
        _initialLocator = locator;
        _queueLocatorSave(locator);
        final progression = locator.locations?.totalProgression;
        if (progression != null && mounted) {
          setState(() => _readingProgress = progression.clamp(0.0, 1.0));
        }
      });
      _syncIfConfigured();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _l10n.readerError(error.toString());
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.restoreHighlightsFailed)));
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
      final choice = await showCompletedDialog<HighlightChoice>(
        context: context,
        builder: (_) => HighlightColorDialog(
          initialColor: widget.settings.highlightColor,
          initialStyle: widget.settings.highlightWithBackground
              ? DecorationStyle.highlight
              : DecorationStyle.underline,
        ),
      );
      if (!mounted || choice == null) return;
      await widget.settings.setHighlightColor(choice.color);
      await widget.settings.setHighlightWithBackground(
        choice.style == DecorationStyle.highlight,
      );
      if (!mounted) return;
      await _saveHighlight(
        locator,
        selectedText,
        choice.color,
        style: choice.style,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.highlightColorFailed)));
      }
    } finally {
      if (mounted) setState(() => _isChoosingHighlight = false);
    }
  }

  Future<void> _saveHighlight(
    Locator locator,
    String? selectedText,
    Color color, {
    required DecorationStyle style,
  }) async {
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
      style: ReaderDecorationStyle(style: style, tint: color),
    );
    final decorations = [..._decorations, decoration];
    try {
      await _storage.saveDecorations(widget.book.id, decorations);
      await _readium.applyDecorations('edureader', decorations);
      await HighlightService.saveHighlight(highlight);
      unawaited(widget.onBookStateChanged?.call());
      if (!mounted) return;
      setState(() {
        _decorations = decorations;
        _selectedTextEvent = null;
        _isSavingHighlight = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingHighlight = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.highlightSaveFailed(error.toString()))),
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
        title: Text(_l10n.deleteHighlight),
        content: Text(
          decoration.locator.text?.highlight ?? _l10n.confirmDeleteHighlight,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_l10n.delete),
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
    unawaited(widget.onBookStateChanged?.call());
    if (!mounted) return;
    setState(() => _decorations = remaining);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_l10n.highlightDeleted)));
  }

  Future<void> _applyHighlight(SelectionActionEvent event) {
    // The system context menu is the quick action: reuse the most recently
    // chosen color without interrupting reading with the color picker.
    return _saveHighlight(
      event.locator,
      event.selectedText,
      widget.settings.highlightColor,
      style: _selectedHighlightStyle,
    );
  }

  DecorationStyle get _selectedHighlightStyle =>
      widget.settings.highlightWithBackground
      ? DecorationStyle.highlight
      : DecorationStyle.underline;

  Future<void> _applyNote(SelectionActionEvent event) async {
    final text = event.selectedText ?? event.locator.text?.highlight ?? '';
    if (text.trim().isEmpty || !mounted) return;

    final controller = TextEditingController();
    final note = await showCompletedDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n.addNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          decoration: InputDecoration(hintText: _l10n.noteHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(_l10n.save),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_l10n.annotationsExported(count))));
  }

  Future<void> _syncIfConfigured() async {
    try {
      final baseUrl = await _sync.getBaseUrl();
      if (baseUrl == null || baseUrl.isEmpty) return;

      final count = await _sync.syncBook(widget.book);
      if (!mounted || count == 0) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.annotationsSynced)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.automaticSyncFailed(error.toString()))),
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
          title: Text(_l10n.configureFreewise),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: _l10n.freewiseUrl),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(_l10n.saveAndSync),
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
            count == 0 ? _l10n.noNewAnnotations : _l10n.annotationsSent,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('FreeWise sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.freewiseSyncFailed(error.toString()))),
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
                  tooltip: _l10n.fullscreen,
                  icon: const Icon(Icons.fullscreen),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 21,
                  onPressed: _openTableOfContents,
                  tooltip: _l10n.readerToc,
                  icon: const Icon(Icons.menu_book_outlined),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 21,
                  onPressed: _openBookmarks,
                  tooltip: _l10n.readerBookmarks,
                  icon: const Icon(Icons.bookmarks_outlined),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 21,
                  onPressed: _editAppearance,
                  tooltip: _l10n.readerAppearance,
                  icon: const Icon(Icons.text_fields),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 21,
                  onPressed: _isSearching ? null : _searchInBook,
                  tooltip: _l10n.searchInBook,
                  icon: _isSearching
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: _l10n.readerMore,
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
                    tooltip: _l10n.exitFullscreen,
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
              label: Text(
                _isSavingHighlight ? _l10n.saving : _l10n.chooseColor,
              ),
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
      selectionActions: [
        SelectionAction(id: 'copy', title: _l10n.copy),
        SelectionAction(id: 'highlight', title: _l10n.underlineAction),
        SelectionAction(id: 'note', title: _l10n.addNote),
      ],
      onReaderReady: _restoreDecorations,
      onTextSelected: _rememberSelection,
      onSelectionAction: _handleSelectionAction,
      onDecorationInteraction: _removeDecoration,
    );
  }
}
