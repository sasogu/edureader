import 'package:file_picker/file_picker.dart';
import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:flutter/material.dart';

import '../data/library_storage.dart';
import '../../reader/presentation/reader_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final LibraryStorage _storage = LibraryStorage();
  final List<EpubBook> _books = [];
  bool _isLoading = false;

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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ReaderPage(book: book)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openStoredBook(EpubBook book) {
    _openBook(book);
  }

  @override
  Widget build(BuildContext context) {
    final hasBooks = _books.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduReader'),
        actions: [
          IconButton(
            onPressed: () {},
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _pickEpub,
        icon: const Icon(Icons.add),
        label: const Text('Añadir EPUB'),
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

class _BookList extends StatelessWidget {
  const _BookList({
    required this.books,
    required this.onOpenBook,
    required this.onPickEpub,
  });

  final List<EpubBook> books;
  final ValueChanged<EpubBook> onOpenBook;
  final VoidCallback onPickEpub;

  @override
  Widget build(BuildContext context) {
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
            Text('${books.length} EPUB'),
          ],
        ),
        const SizedBox(height: 16),
        ...books.map(
          (book) => Card(
            child: ListTile(
              leading: const Icon(Icons.book_outlined),
              title: Text(book.metadata.title),
              subtitle: Text(book.metadata.creator ?? 'Autor desconocido'),
              onTap: () => onOpenBook(book),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onPickEpub,
          icon: const Icon(Icons.add),
          label: const Text('Añadir otro EPUB'),
        ),
      ],
    );
  }
}
