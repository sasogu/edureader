import 'package:file_picker/file_picker.dart';
import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:flutter/material.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/completed_dialog.dart';
import '../../reader/data/freewise_sync.dart';
import '../../reader/data/nextcloud_sync.dart';
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
  bool _isLoading = false;
  bool _isSettingsOpen = false;
  bool _isNextcloudSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final books = await _storage.loadBooks();
    if (!mounted) return;
    setState(() {
      _books
        ..clear()
        ..addAll(books);
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(book: book, settings: widget.settings),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openStoredBook(EpubBook book) {
    _openBook(book);
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
      if (!mounted) return;
      setState(() {
        _books
          ..clear()
          ..addAll(refreshedBooks);
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
    if (action != null && mounted) _handleNextcloudAction(action);
  }

  void _handleNextcloudAction(_NextcloudAction action) {
    switch (action) {
      case _NextcloudAction.sync:
        _syncWithNextcloud();
      case _NextcloudAction.configure:
        _configureNextcloud();
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
            icon: _isNextcloudSyncing
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
                      onOpenBook: _openStoredBook,
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
    required this.onOpenBook,
    required this.onPickEpub,
  });

  final List<EpubBook> books;
  final ValueChanged<EpubBook> onOpenBook;
  final VoidCallback onPickEpub;

  @override
  State<_BookList> createState() => _BookListState();
}

class _BookListState extends State<_BookList> {
  String _query = '';
  _LibrarySort _sort = _LibrarySort.recentlyAdded;

  List<EpubBook> get _visibleBooks {
    final query = _query.trim().toLowerCase();
    final filtered = widget.books.where((book) {
      return query.isEmpty ||
          book.metadata.title.toLowerCase().contains(query) ||
          (book.metadata.creator ?? '').toLowerCase().contains(query);
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
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 480,
                              mainAxisExtent: 100,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 4,
                            ),
                        itemCount: visibleBooks.length,
                        itemBuilder: (context, index) =>
                            _bookCard(visibleBooks[index]),
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

  Widget _bookCard(EpubBook book) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: const Icon(Icons.book_outlined),
      title: Text(
        book.metadata.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        book.metadata.creator ?? 'Autor desconocido',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => widget.onOpenBook(book),
    ),
  );
}
