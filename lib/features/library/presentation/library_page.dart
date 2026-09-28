import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/completed_dialog.dart';
import '../../reader/data/freewise_sync.dart';
import '../../reader/data/nextcloud_sync.dart';
import '../data/cover_extractor.dart';
import '../data/library_storage.dart';
import '../../reader/presentation/reader_page.dart';

enum _NextcloudAction { sync, configure }

class LibraryPage extends StatefulWidget {
  const LibraryPage({required this.settings, super.key});

  final AppSettings settings;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final LibraryStorage _storage = LibraryStorage();
  final FreeWiseSync _sync = FreeWiseSync();
  final NextcloudSync _nextcloud = NextcloudSync();
  final List<EpubBook> _books = [];
  final Map<String, List<String>> _bookTags = {};
  bool _isLoading = false;
  bool _isSettingsOpen = false;
  bool _isNextcloudSyncing = false;
  int _autoSyncs = 0;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final books = await _storage.loadBooks();
    final tags = <String, List<String>>{};
    for (final book in books) {
      tags[book.id] = await _storage.loadBookTags(book.id);
    }
    if (!mounted) return;
    setState(() {
      _books
        ..clear()
        ..addAll(books);
      _bookTags
        ..clear()
        ..addAll(tags);
      _isLoading = false;
    });
  }

  Future<void> _pickEpub() async {
    if (_isNextcloudSyncing) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: false,
    );

    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final path = file.path;
    if (path == null) {
      _showError('No se ha podido obtener la ruta del EPUB.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final book = await _storage.importBook(path);
      if (!mounted) return;

      setState(() {
        _books.removeWhere((item) => item.id == book.id);
        _books.add(book);
        _bookTags[book.id] = [];
        _isLoading = false;
      });

      await _openBook(book);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('No se ha podido abrir el EPUB: $error');
    }
  }

  Future<void> _openBook(EpubBook book) async {
    // Al entrar se trae la posición remota sin subir el EPUB, para no
    // retrasar la apertura; al salir se publica el estado y, si falta, el libro.
    // Si la respuesta llega cuando el lector ya está abierto, se descarta:
    // aplicarla o publicarla entonces pisaría la posición que se está leyendo.
    var readerOpened = false;
    final shouldOpen = await _autoSyncBook(
      book,
      uploadIfMissing: false,
      timeout: const Duration(seconds: 5),
      isCancelled: () => readerOpened,
    );
    readerOpened = true;
    if (!mounted) return;
    if (!shouldOpen) {
      await _removeBookAfterRemoteDelete(book, showMessage: true);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          book: book,
          settings: widget.settings,
          onAppBackground: () async {
            await _autoSyncBook(book);
          },
        ),
      ),
    );
    if (!mounted) return;
    unawaited(
      _autoSyncBook(book).then<void>((shouldKeep) async {
        if (!shouldKeep && mounted) {
          await _removeBookAfterRemoteDelete(book);
        }
      }),
    );
  }

  Future<void> _removeBookAfterRemoteDelete(
    EpubBook book, {
    bool showMessage = false,
  }) async {
    await _storage.removeBook(book);
    if (!mounted) return;
    setState(() {
      _books.removeWhere((item) => item.id == book.id);
      _bookTags.remove(book.id);
    });
    if (showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este libro se eliminó desde otro dispositivo.'),
        ),
      );
    }
  }

  // Sincronización silenciosa: sin conexión configurada, sin red o con el
  // servidor lento, se sigue leyendo con el estado local.
  Future<bool> _autoSyncBook(
    EpubBook book, {
    bool uploadIfMissing = true,
    Duration timeout = const Duration(minutes: 2),
    bool Function()? isCancelled,
  }) async {
    // No se descarta aunque haya otra sincronización en marcha: NextcloudSync
    // las pone en fila, y saltarse la del cierre perdería la última posición.
    final connection = await _nextcloud.loadConnection();
    if (connection == null || connection.appPassword.isEmpty) return true;
    if (!mounted) return true;
    setState(() => _autoSyncs++);
    try {
      return await _nextcloud
          .syncBook(
            book,
            uploadIfMissing: uploadIfMissing,
            isCancelled: isCancelled,
          )
          .timeout(timeout);
    } catch (_) {
      // La sincronización manual muestra los errores; la automática no molesta.
      return true;
    } finally {
      if (mounted) setState(() => _autoSyncs--);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openStoredBook(EpubBook book) {
    _openBook(book);
  }

  Future<void> _deleteBook(EpubBook book) async {
    if (_isNextcloudSyncing || _autoSyncs > 0) {
      _showError('Espera a que termine la sincronización antes de eliminar.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar libro'),
        content: Text(
          '«${book.metadata.title}» se eliminará de este dispositivo y de Nextcloud. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _nextcloud.deleteBook(book);
      await _storage.removeBook(book);
      if (!mounted) return;
      setState(() {
        _books.removeWhere((item) => item.id == book.id);
        _bookTags.remove(book.id);
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Libro eliminado de este dispositivo y Nextcloud.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('No se pudo eliminar el libro: $error');
    }
  }

  Future<void> _saveBookTags(EpubBook book, List<String> tags) async {
    try {
      await _storage.saveBookTags(book.id, tags);
      if (!mounted) return;
      setState(() => _bookTags[book.id] = List.of(tags));
    } catch (error) {
      if (mounted) _showError('No se pudieron guardar las etiquetas: $error');
    }
  }

  Future<bool> _configureNextcloud() async {
    final existing = await _nextcloud.loadConnection();
    if (!mounted) return false;
    final serverController = TextEditingController(
      text: existing?.serverUrl ?? '',
    );
    final usernameController = TextEditingController(
      text: existing?.username ?? '',
    );
    final passwordController = TextEditingController();
    String? validationError;
    final configuration =
        await showCompletedDialog<
          ({String serverUrl, String username, String appPassword})
        >(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Conectar con Nextcloud'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: serverController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'URL de Nextcloud',
                        hintText: 'https://nube.ejemplo.com',
                      ),
                    ),
                    TextField(
                      controller: usernameController,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Usuario'),
                    ),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Contraseña de aplicación',
                        helperText: existing?.appPassword.isNotEmpty == true
                            ? 'Déjala vacía para conservar la guardada.'
                            : 'Créala desde Seguridad en Nextcloud.',
                        errorText: validationError,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'La contraseña se guarda cifrada en el almacenamiento seguro del dispositivo.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final serverUrl = serverController.text.trim();
                    final username = usernameController.text.trim();
                    final uri = Uri.tryParse(serverUrl);
                    if (uri == null ||
                        !uri.hasAuthority ||
                        uri.host.isEmpty ||
                        uri.scheme != 'https' ||
                        uri.hasQuery ||
                        uri.hasFragment ||
                        uri.userInfo.isNotEmpty) {
                      setDialogState(
                        () => validationError =
                            'Usa una URL segura que empiece por https://.',
                      );
                      return;
                    }
                    if (username.isEmpty) {
                      setDialogState(
                        () =>
                            validationError = 'Indica el usuario de Nextcloud.',
                      );
                      return;
                    }
                    if (passwordController.text.isEmpty &&
                        existing?.appPassword.isNotEmpty != true) {
                      setDialogState(
                        () => validationError =
                            'Introduce una contraseña de aplicación.',
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, (
                      serverUrl: serverUrl,
                      username: username,
                      appPassword: passwordController.text,
                    ));
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        );
    serverController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    if (!mounted || configuration == null) return false;

    try {
      await _nextcloud.saveConnection(
        serverUrl: configuration.serverUrl,
        username: configuration.username,
        appPassword: configuration.appPassword,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conexión de Nextcloud guardada.')),
        );
      }
      return true;
    } catch (error) {
      if (mounted) _showError('No se pudo guardar la conexión: $error');
      return false;
    }
  }

  Future<void> _syncWithNextcloud() async {
    try {
      var connection = await _nextcloud.loadConnection();
      if (connection == null || connection.appPassword.isEmpty) {
        if (!await _configureNextcloud()) return;
        connection = await _nextcloud.loadConnection();
      }
      if (connection == null || connection.appPassword.isEmpty) return;

      setState(() {
        _isNextcloudSyncing = true;
        _isLoading = true;
      });
      final books = await _storage.loadBooks();
      final result = await _nextcloud.syncLibrary(books);
      final refreshedBooks = await _storage.loadBooks();
      final refreshedTags = <String, List<String>>{};
      for (final book in refreshedBooks) {
        refreshedTags[book.id] = await _storage.loadBookTags(book.id);
      }
      if (!mounted) return;
      setState(() {
        _books
          ..clear()
          ..addAll(refreshedBooks);
        _bookTags
          ..clear()
          ..addAll(refreshedTags);
        _isLoading = false;
      });
      final message = result.uploadedBooks == 0 && result.downloadedBooks == 0
          ? 'Biblioteca y lectura sincronizadas con Nextcloud.'
          : 'Nextcloud: ${result.uploadedBooks} EPUB enviados, ${result.downloadedBooks} recibidos.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) _showError('No se pudo sincronizar con Nextcloud: $error');
    } finally {
      if (mounted) setState(() => _isNextcloudSyncing = false);
    }
  }

  // En iPad el PopupMenuButton se cerraba solo; una hoja inferior modal
  // se mantiene abierta hasta que se elige una opción.
  Future<void> _openNextcloudMenu() async {
    final action = await showModalBottomSheet<_NextcloudAction>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sincronizar biblioteca'),
              onTap: () => Navigator.pop(sheetContext, _NextcloudAction.sync),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Configurar Nextcloud'),
              onTap: () =>
                  Navigator.pop(sheetContext, _NextcloudAction.configure),
            ),
          ],
        ),
      ),
    );
    if (action != null && mounted) await _handleNextcloudAction(action);
  }

  Future<void> _handleNextcloudAction(_NextcloudAction action) async {
    switch (action) {
      case _NextcloudAction.sync:
        await _syncWithNextcloud();
      case _NextcloudAction.configure:
        await _configureNextcloud();
    }
  }

  Future<void> _openSettings() async {
    if (_isSettingsOpen) return;
    _isSettingsOpen = true;
    try {
      await _showSettings();
    } finally {
      _isSettingsOpen = false;
    }
  }

  Future<void> _showSettings() async {
    String? currentUrl;
    try {
      currentUrl = await _sync.getBaseUrl();
    } catch (error) {
      if (mounted) {
        _showError('No se pudo cargar la configuración: $error');
      }
      return;
    }
    if (!mounted) return;

    final controller = TextEditingController(text: currentUrl ?? '');
    String? validationError;
    var darkMode = widget.settings.darkMode;
    var sepiaMode = widget.settings.sepiaMode;
    var fontScale = widget.settings.fontScale;
    var lineHeight = widget.settings.lineHeight;
    var pageMargins = widget.settings.pageMargins;
    final configuration =
        await showCompletedDialog<
          ({
            String? url,
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
              title: const Text('Configuración'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'URL del servidor FreeWise',
                        hintText: 'https://freewise.example.com',
                        helperText: 'Incluye http:// o https://',
                        errorText: validationError,
                      ),
                      onChanged: (_) {
                        if (validationError != null) {
                          setDialogState(() => validationError = null);
                        }
                      },
                    ),
                    const Divider(height: 32),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    final uri = value.isEmpty ? null : Uri.tryParse(value);
                    if (value.isNotEmpty &&
                        (uri == null ||
                            !uri.hasAuthority ||
                            uri.host.isEmpty ||
                            !{'http', 'https'}.contains(uri.scheme))) {
                      setDialogState(
                        () => validationError =
                            'Introduce una URL válida que empiece por http:// o https://.',
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, (
                      url: value.isEmpty ? null : value,
                      darkMode: darkMode,
                      sepiaMode: sepiaMode,
                      fontScale: fontScale,
                      lineHeight: lineHeight,
                      pageMargins: pageMargins,
                    ));
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        );
    controller.dispose();

    if (!mounted || configuration == null) return;
    try {
      await widget.settings.updateAppearance(
        darkMode: configuration.darkMode,
        sepiaMode: configuration.sepiaMode,
        fontScale: configuration.fontScale,
        lineHeight: configuration.lineHeight,
        pageMargins: configuration.pageMargins,
      );
      final configuredUrl = configuration.url;
      if (configuredUrl != null) await _sync.setBaseUrl(configuredUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        _showError('No se pudo guardar la configuración: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBooks = _books.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduReader'),
        actions: [
          IconButton(
            tooltip: 'Sincronización Nextcloud',
            onPressed: _isNextcloudSyncing ? null : _openNextcloudMenu,
            icon: _isNextcloudSyncing || _autoSyncs > 0
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
          ),
          IconButton(
            onPressed: _openSettings,
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : hasBooks
                  ? _BookList(
                      books: _books,
                      bookTags: _bookTags,
                      onOpenBook: _openStoredBook,
                      onDeleteBook: _deleteBook,
                      onSaveBookTags: _saveBookTags,
                      onPickEpub: _pickEpub,
                    )
                  : _EmptyLibrary(onPickEpub: _pickEpub),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onPickEpub});

  final VoidCallback onPickEpub;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Tu biblioteca está vacía',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'EduReader empieza centrado en EPUB, lectura cómoda y subrayados que podremos enviar a FreeWise.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPickEpub,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Elegir un EPUB'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LibrarySort { recentlyAdded, title, author }

class _BookList extends StatefulWidget {
  const _BookList({
    required this.books,
    required this.bookTags,
    required this.onOpenBook,
    required this.onDeleteBook,
    required this.onSaveBookTags,
    required this.onPickEpub,
  });

  final List<EpubBook> books;
  final Map<String, List<String>> bookTags;
  final ValueChanged<EpubBook> onOpenBook;
  final ValueChanged<EpubBook> onDeleteBook;
  final void Function(EpubBook, List<String>) onSaveBookTags;
  final VoidCallback onPickEpub;

  @override
  State<_BookList> createState() => _BookListState();
}

class _BookListState extends State<_BookList> {
  final CoverCache _covers = CoverCache();
  String _query = '';
  _LibrarySort _sort = _LibrarySort.recentlyAdded;
  final Set<String> _selectedTags = {};

  @override
  void didUpdateWidget(covariant _BookList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentTags = widget.bookTags.values.expand((tags) => tags).toSet();
    _selectedTags.removeWhere((tag) => !currentTags.contains(tag));
  }

  List<String> get _allTags =>
      widget.bookTags.values.expand((tags) => tags).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  Future<void> _editTags(EpubBook book) async {
    final tags = List<String>.of(widget.bookTags[book.id] ?? const []);
    final controller = TextEditingController();
    final updatedTags = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void addTag() {
            final value = controller.text.trim();
            if (value.isEmpty ||
                tags.any((tag) => tag.toLowerCase() == value.toLowerCase())) {
              return;
            }
            setDialogState(() {
              tags.add(value);
              tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              controller.clear();
            });
          }

          return AlertDialog(
            title: const Text('Etiquetas del libro'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    book.metadata.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Nueva etiqueta',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => addTag(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Añadir etiqueta',
                        onPressed: addTag,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (tags.isEmpty)
                    const Text('Este libro todavía no tiene etiquetas.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final tag in tags)
                          InputChip(
                            label: Text(tag),
                            onDeleted: () =>
                                setDialogState(() => tags.remove(tag)),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, tags),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (!mounted || updatedTags == null) return;
    widget.onSaveBookTags(book, updatedTags);
  }

  List<EpubBook> get _visibleBooks {
    final query = _query.trim().toLowerCase();
    final filtered = widget.books.where((book) {
      final matchesSearch =
          query.isEmpty ||
          book.metadata.title.toLowerCase().contains(query) ||
          (book.metadata.creator ?? '').toLowerCase().contains(query);
      final tags = widget.bookTags[book.id] ?? const <String>[];
      final matchesTags = _selectedTags.every(tags.contains);
      return matchesSearch && matchesTags;
    }).toList();
    switch (_sort) {
      case _LibrarySort.recentlyAdded:
        break;
      case _LibrarySort.title:
        filtered.sort(
          (a, b) => a.metadata.title.toLowerCase().compareTo(
            b.metadata.title.toLowerCase(),
          ),
        );
      case _LibrarySort.author:
        filtered.sort(
          (a, b) => (a.metadata.creator ?? '').toLowerCase().compareTo(
            (b.metadata.creator ?? '').toLowerCase(),
          ),
        );
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final visibleBooks = _visibleBooks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Biblioteca',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            Semantics(
              label: '${widget.books.length} libros en la biblioteca',
              child: ExcludeSemantics(
                child: Text('${widget.books.length} EPUB'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar en la biblioteca',
            hintText: 'Título o autor',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
        ),
        if (_allTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Filtrar por etiquetas',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (_selectedTags.isNotEmpty) ...[
                const Spacer(),
                TextButton(
                  onPressed: () => setState(_selectedTags.clear),
                  child: const Text('Limpiar'),
                ),
              ],
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 112),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final tag in _allTags)
                    FilterChip(
                      label: Text(tag),
                      selected: _selectedTags.contains(tag),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          if (_allTags.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Al elegir varias, se muestran los libros que tienen todas.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: 8),
        DropdownButtonFormField<_LibrarySort>(
          initialValue: _sort,
          decoration: const InputDecoration(
            labelText: 'Ordenar por',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(
              value: _LibrarySort.recentlyAdded,
              child: Text('Añadidos recientemente'),
            ),
            DropdownMenuItem(value: _LibrarySort.title, child: Text('Título')),
            DropdownMenuItem(value: _LibrarySort.author, child: Text('Autor')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _sort = value);
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: visibleBooks.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty
                        ? 'La biblioteca está vacía.'
                        : 'No hay libros que coincidan con «$_query».',
                    textAlign: TextAlign.center,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 640) {
                      // Pantallas anchas: estantería de portadas.
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 180,
                              childAspectRatio: 0.5,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: visibleBooks.length,
                        itemBuilder: (context, index) =>
                            _bookTile(visibleBooks[index]),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: visibleBooks.length,
                      itemBuilder: (context, index) =>
                          _bookCard(visibleBooks[index]),
                    );
                  },
                ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onPickEpub,
          icon: const Icon(Icons.add),
          label: const Text('Añadir otro EPUB'),
        ),
      ],
    );
  }

  Widget _cover(EpubBook book) =>
      _BookCover(cover: _covers.coverFor(book.id), title: book.metadata.title);

  Widget _bookCard(EpubBook book) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => widget.onOpenBook(book),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(width: 56, height: 84, child: _cover(book)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.metadata.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.metadata.creator ?? 'Autor desconocido',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if ((widget.bookTags[book.id] ?? []).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 0,
                      children: [
                        for (final tag in widget.bookTags[book.id]!)
                          Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Editar etiquetas',
              onPressed: () => _editTags(book),
              icon: const Icon(Icons.sell_outlined),
            ),
            IconButton(
              tooltip: 'Eliminar libro',
              onPressed: () => widget.onDeleteBook(book),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _bookTile(EpubBook book) => InkWell(
    onTap: () => widget.onOpenBook(book),
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _cover(book),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Column(
                    children: [
                      Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Editar etiquetas',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _editTags(book),
                          icon: const Icon(Icons.sell_outlined),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Eliminar libro',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => widget.onDeleteBook(book),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.metadata.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            book.metadata.creator ?? 'Autor desconocido',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if ((widget.bookTags[book.id] ?? []).isNotEmpty)
            Text(
              widget.bookTags[book.id]!.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    ),
  );
}

/// Portada del libro, o un marcador con icono si el EPUB no trae imagen.
class _BookCover extends StatelessWidget {
  const _BookCover({required this.cover, required this.title});

  final Future<File?> cover;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.menu_book_outlined, color: colors.onSurfaceVariant),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: ExcludeSemantics(
        child: FutureBuilder<File?>(
          future: cover,
          builder: (context, snapshot) {
            final file = snapshot.data;
            if (file == null) return placeholder;
            return Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: 360,
              errorBuilder: (_, _, _) => placeholder,
            );
          },
        ),
      ),
    );
  }
}
