import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart' show DecorationStyle;
import 'package:pdfrx/pdfrx.dart' as pdf;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/app_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/data/pdf_storage.dart';
import '../data/nextcloud_sync.dart';
import '../data/pdf_annotation_storage.dart';
import '../data/pdf_selection.dart';
import '../data/readium_storage.dart';
import 'highlight_color_dialog.dart';

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({
    required this.document,
    required this.settings,
    super.key,
  });

  final PdfDocument document;
  final AppSettings settings;

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  final pdf.PdfViewerController _controller = pdf.PdfViewerController();
  final PdfAnnotationStorage _storage = PdfAnnotationStorage();
  final NextcloudSync _sync = NextcloudSync();
  List<PdfAnnotation> _annotations = [];
  List<pdf.PdfTextRanges> _selections = [];
  int _initialPage = 1;
  int _currentPage = 1;
  bool _loading = true;
  bool _saving = false;
  late String _annotationKey;
  String? _error;

  String get _pageKey => 'pdf_page_${widget.document.id}';
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      _annotationKey = await widget.document.contentHash();
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getInt(_pageKey);
      final oldLocator = savedPage == null
          ? await ReadiumStorage().loadLocator(widget.document.id)
          : null;
      final annotations = await _storage.load(_annotationKey);
      if (!mounted) return;
      setState(() {
        _initialPage = max(
          1,
          savedPage ?? oldLocator?.locations?.position ?? 1,
        );
        _currentPage = _initialPage;
        _annotations = annotations;
        _loading = false;
      });
      unawaited(_syncIfConfigured());
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _syncIfConfigured() async {
    try {
      final connection = await _sync.loadConnection();
      if (connection == null || connection.appPassword.isEmpty) return;
      await _sync.syncPdfAnnotations(widget.document);
      final annotations = await _storage.load(_annotationKey);
      if (mounted) setState(() => _annotations = annotations);
    } catch (_) {
      // Keep local edits available; the next edit or opening retries.
    }
  }

  void _onPageChanged(int? page) {
    if (page == null) return;
    _currentPage = page;
    unawaited(_savePage(page));
  }

  Future<void> _addPageNote() async {
    final note = await _editNote();
    if (!mounted || note == null || note.isEmpty) return;
    final annotation = PdfAnnotation(
      id: '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}',
      pageIndex: _currentPage - 1,
      text: '',
      rects: const [],
      color: widget.settings.highlightColor.toARGB32(),
      note: note,
      modifiedAt: DateTime.now().toUtc(),
    );
    await _storage.merge(_annotationKey, [annotation]);
    final annotations = await _storage.load(_annotationKey);
    if (mounted) setState(() => _annotations = annotations);
    unawaited(_syncIfConfigured());
  }

  Future<void> _savePage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pageKey, page);
  }

  void _onSelectionChanged(List<pdf.PdfTextRanges> selections) {
    final selected = selections.where((item) => item.isNotEmpty).toList();
    if (!mounted || (selected.isEmpty && _selections.isEmpty)) return;
    setState(() => _selections = selected);
  }

  Future<void> _saveSelection({required bool withNote}) async {
    final selections = List<pdf.PdfTextRanges>.of(_selections);
    if (selections.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final choice = await showDialog<HighlightChoice>(
        context: context,
        builder: (_) => HighlightColorDialog(
          initialColor: widget.settings.highlightColor,
          initialStyle: widget.settings.highlightWithBackground
              ? DecorationStyle.highlight
              : DecorationStyle.underline,
        ),
      );
      if (!mounted || choice == null) return;
      String? note;
      if (withNote) {
        note = await _editNote();
        if (!mounted || note == null) return;
      }
      final added = <PdfAnnotation>[];
      for (final selection in selections) {
        final rects = pdfRectsForSelection(selection);
        if (rects.isEmpty) continue;
        added.add(
          PdfAnnotation(
            id: '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}',
            pageIndex: selection.pageNumber - 1,
            text: selection.text.trim(),
            rects: rects,
            color: choice.color.toARGB32(),
            underline: choice.style == DecorationStyle.underline,
            note: added.isEmpty ? note : null,
            modifiedAt: DateTime.now().toUtc(),
          ),
        );
      }
      if (added.isEmpty) return;
      await _storage.merge(_annotationKey, added);
      if (!mounted) return;
      setState(() {
        _annotations = [..._annotations, ...added];
        _selections = [];
      });
      unawaited(_syncIfConfigured());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _editNote({String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.addNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          decoration: InputDecoration(hintText: _l10n.noteHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(_l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    return note;
  }

  Future<void> _update(PdfAnnotation item, {bool delete = false}) async {
    final note = delete ? null : await _editNote(initial: item.note ?? '');
    if (!mounted || (!delete && note == null)) return;
    await _storage.merge(_annotationKey, [
      item.copyWith(
        note: note,
        deleted: delete,
        modifiedAt: DateTime.now().toUtc(),
      ),
    ]);
    final annotations = await _storage.load(_annotationKey);
    if (mounted) setState(() => _annotations = annotations);
    unawaited(_syncIfConfigured());
  }

  List<Widget> _overlays(
    BuildContext context,
    Rect pageRect,
    pdf.PdfPage page,
  ) {
    final overlays = <Widget>[];
    for (final item in _annotations) {
      if (item.deleted || item.pageIndex != page.pageNumber - 1) continue;
      for (final rect in item.rects) {
        final pdfRect = pdf.PdfRect(
          rect.x,
          rect.y,
          rect.x + rect.width,
          rect.y - rect.height,
        );
        final display = pdfRect.toRect(
          page: page,
          scaledPageSize: pageRect.size,
        );
        overlays.add(
          Positioned.fromRect(
            rect: display,
            child: IgnorePointer(
              child: item.underline
                  ? Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(height: 2, color: Color(item.color)),
                    )
                  : ColoredBox(
                      color: Color(item.color).withValues(alpha: 0.35),
                    ),
            ),
          ),
        );
      }
    }
    return overlays;
  }

  Future<void> _showAnnotations() async {
    final items = _annotations.where((item) => !item.deleted).toList()
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            children: [
              ListTile(title: Text(_l10n.viewAnnotations)),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(
                        item.text.isEmpty
                            ? 'PDF · ${item.pageIndex + 1}'
                            : item.text,
                        maxLines: 2,
                      ),
                      subtitle: Text(
                        'PDF · ${item.pageIndex + 1}${item.note?.isNotEmpty == true ? ' · ${item.note}' : ''}',
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        unawaited(
                          _controller.goToPage(pageNumber: item.pageIndex + 1),
                        );
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          Navigator.pop(sheetContext);
                          unawaited(_update(item, delete: value == 'delete'));
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'note',
                            child: Text(_l10n.addNote),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(_l10n.delete),
                          ),
                        ],
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
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.document.title),
      actions: [
        IconButton(
          tooltip: _l10n.addNote,
          icon: const Icon(Icons.note_add_outlined),
          onPressed: _loading ? null : _addPageNote,
        ),
        IconButton(
          tooltip: _l10n.viewAnnotations,
          icon: const Icon(Icons.format_color_fill_outlined),
          onPressed: _loading ? null : _showAnnotations,
        ),
      ],
    ),
    body: _error != null
        ? Center(child: Text(_l10n.readerError(_error!)))
        : _loading
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              pdf.PdfViewer.file(
                widget.document.path,
                controller: _controller,
                initialPageNumber: _initialPage,
                params: pdf.PdfViewerParams(
                  enableTextSelection: true,
                  onPageChanged: _onPageChanged,
                  onTextSelectionChange: _onSelectionChanged,
                  pageOverlaysBuilder: _overlays,
                ),
              ),
              if (_selections.isNotEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () => _saveSelection(withNote: false),
                              child: Text(_l10n.underlineAction),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: _saving
                                  ? null
                                  : () => _saveSelection(withNote: true),
                              child: Text(_l10n.addNote),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );
}
