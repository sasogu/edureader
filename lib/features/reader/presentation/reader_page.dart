import 'package:advanced_epub_reader/advanced_epub_reader.dart';
import 'package:flutter/material.dart';

import '../data/reading_progress_storage.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({required this.book, super.key});

  final EpubBook book;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final ReadingProgressStorage _progressStorage = ReadingProgressStorage();
  ReadingProgress? _progress;
  bool _isLoadingProgress = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
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

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (_isLoadingProgress) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.book.metadata.title)),
      body: EpubViewer(
        book: widget.book,
        initialChapterIndex: progress?.currentChapterIndex ?? 0,
        initialPosition: progress?.chapterProgress ?? 0,
        showControls: true,
        showTableOfContents: true,
        onProgressChanged: _saveProgress,
        onNoteSaved: _saveNote,
      ),
    );
  }
}
