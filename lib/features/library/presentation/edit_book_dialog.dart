import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';

class EditBookDialog extends ConsumerStatefulWidget {
  final Book book;

  const EditBookDialog({super.key, required this.book});

  @override
  ConsumerState<EditBookDialog> createState() => _EditBookDialogState();
}

class _EditBookDialogState extends ConsumerState<EditBookDialog> {
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _genreController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book.title);
    _authorController = TextEditingController(text: widget.book.author);
    _genreController = TextEditingController(text: widget.book.genre);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newTitle = _titleController.text.trim();
    final newAuthor = _authorController.text.trim();
    final newGenre = _genreController.text.trim();

    if (newTitle.isEmpty) return;

    final updatedBook = widget.book
      ..title = newTitle
      ..author = newAuthor.isEmpty ? 'Unknown Author' : newAuthor
      ..genre = newGenre.isEmpty ? 'General' : newGenre;

    updatedBook.coverUrl = widget.book.coverUrl; // Preserve existing or updated fields not in UI
    updatedBook.coverColor = widget.book.coverColor;

    await ref.read(bookRepositoryProvider).updateBook(updatedBook);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Book Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _authorController,
              decoration: const InputDecoration(labelText: 'Author'),
              textCapitalization: TextCapitalization.words,
            ),
             const SizedBox(height: 16),
            TextField(
              controller: _genreController,
              decoration: const InputDecoration(labelText: 'Genre'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
