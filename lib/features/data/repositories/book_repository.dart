import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../models/book.dart';
import '../models/note.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository();
});

class BookRepository {
  static Isar? _isar;
  final _uuid = const Uuid();

  Future<void> initialize() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([BookSchema, NoteSchema], directory: dir.path);
  }

  Isar get isar {
    if (_isar == null) throw Exception('Isar not initialized. Call initialize() first.');
    return _isar!;
  }

  Future<Book> addBook(File file) async {
    // 1. Get Application Documents Directory
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/books');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    // 2. Generate new unique filename to avoid conflicts
    final originalName = file.path.split(Platform.pathSeparator).last;
    final extension = originalName.split('.').last;
    final uuid = _uuid.v4();
    final newPath = '${booksDir.path}/$uuid.$extension';

    // 3. Copy file to persistent storage
    final persistentFile = await file.copy(newPath);

    // 4. Create Book Object
    final book = Book()..uuid = uuid..filePath = persistentFile.path;
    
    // 5. Parse Metadata (using original name)
    String nameWithoutExtension = originalName.replaceAll(RegExp(r'\.(pdf|epub)$', caseSensitive: false), '').replaceAll('_', ' ');

    String title = nameWithoutExtension;
    String author = 'Unknown Author';
    String genre = 'General';
    String searchQuery = nameWithoutExtension.replaceAll('-', ' ').replaceAll(' by ', ' ').trim();

    try {
      final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=${Uri.encodeComponent(searchQuery)}&maxResults=1');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['totalItems'] > 0 && data['items'] != null && data['items'].isNotEmpty) {
          final volumeInfo = data['items'][0]['volumeInfo'];
          title = volumeInfo['title'] ?? title;
          if (volumeInfo['authors'] != null && (volumeInfo['authors'] as List).isNotEmpty) author = (volumeInfo['authors'] as List).first.toString();
          if (volumeInfo['categories'] != null && (volumeInfo['categories'] as List).isNotEmpty) genre = _simplifyGenre((volumeInfo['categories'] as List).first.toString());
          if (volumeInfo['imageLinks'] != null && volumeInfo['imageLinks']['thumbnail'] != null) book.coverUrl = volumeInfo['imageLinks']['thumbnail'];
        } else {
          final parsed = _parseFilename(nameWithoutExtension);
          title = parsed['title']!; author = parsed['author']!; genre = _inferGenre(title, file.path);
        }
      } else {
         final parsed = _parseFilename(nameWithoutExtension);
         title = parsed['title']!; author = parsed['author']!; genre = _inferGenre(title, file.path);
      }
    } catch (e) {
      final parsed = _parseFilename(nameWithoutExtension);
      title = parsed['title']!; author = parsed['author']!; genre = _inferGenre(title, file.path);
    }

    book.title = title; book.author = author; book.genre = genre;
    await isar.writeTxn(() async { await isar.books.put(book); });
    return book;
  }

  String _simplifyGenre(String rawGenre) {
    final lower = rawGenre.toLowerCase();
    if (lower.contains('self-help') || lower.contains('growth') || lower.contains('motivation')) return 'Self-Help';
    if (lower.contains('biography') || lower.contains('memoir')) return 'Biography';
    if (lower.contains('fiction')) {
      if (lower.contains('sci-fi') || lower.contains('science')) return 'Sci-Fi';
      if (lower.contains('fantasy')) return 'Fantasy';
      if (lower.contains('romance')) return 'Romance';
      if (lower.contains('horror')) return 'Horror';
      if (lower.contains('thriller') || lower.contains('mystery')) return 'Thriller';
      return 'Fiction'; 
    }
    if (lower.contains('history')) return 'History';
    if (lower.contains('science')) return 'Science';
    if (lower.contains('tech') || lower.contains('computer')) return 'Technical';
    if (lower.contains('business')) return 'Business';
    if (lower.contains('philosophy')) return 'Philosophy';
    if (lower.contains('psychology')) return 'Psychology';
    if (lower.contains('art')) return 'Art & Design';
    if (rawGenre.length < 20 && !rawGenre.contains('/')) return rawGenre;
    return 'General';
  }

  Map<String, String> _parseFilename(String name) {
     String title = name; String author = 'Unknown Author';
    if (name.contains(' by ')) {
      final parts = name.split(' by '); title = parts[0].trim(); author = parts[1].trim();
    } else if (name.contains(' - ')) {
      final parts = name.split(' - '); title = parts[0].trim(); author = parts.length > 1 ? parts[1].trim() : 'Unknown Author';
    }
    return {'title': title, 'author': author};
  }

  String _inferGenre(String title, String path) {
    final text = '$title $path'.toLowerCase();
    if (text.contains('sci-fi')) return 'Sci-Fi';
    if (text.contains('fantasy')) return 'Fantasy';
    return 'General';
  }

  Stream<List<Book>> watchBooks() => isar.books.where().watch(fireImmediately: true);
  Future<List<Book>> getAllBooks() async => await isar.books.where().findAll();
  Future<Book?> getBook(int id) async => await isar.books.get(id);
  Future<void> updateBook(Book book) async { await isar.writeTxn(() async { await isar.books.put(book); }); }
  Future<void> deleteBook(int id) async { await isar.writeTxn(() async { final book = await isar.books.get(id); if (book != null) await isar.notes.filter().bookIdEqualTo(book.uuid).deleteAll(); await isar.books.delete(id); }); }
  Future<void> updateBookProgress(int id, int page, int total) async { await isar.writeTxn(() async { final book = await isar.books.get(id); if (book != null) { book.lastReadPosition = page; book.totalPages = total; book.lastReadTime = DateTime.now(); await isar.books.put(book); } }); }

  Future<Note> addNote({
    required String bookId,
    required String highlight,
    String comment = '',
    String title = '',
    String subtitle = '',
    String color = '0xFFFFF9C4',
    bool isBold = false,
    bool isItalic = false,
    double fontSize = 16.0,
    String fontFamily = 'Kalam',
  }) async {
    final note = Note()
      ..bookId = bookId
      ..highlight = highlight
      ..comment = comment
      ..title = title
      ..subtitle = subtitle
      ..color = color
      ..isBold = isBold
      ..isItalic = isItalic
      ..fontSize = fontSize
      ..fontFamily = fontFamily;

    await isar.writeTxn(() async {
      await isar.notes.put(note);
    });

    return note;
  }

  Future<List<Note>> getNotesForBook(String bookUuid) async => await isar.notes.filter().bookIdEqualTo(bookUuid).findAll();
  Stream<List<Note>> watchNotesForBook(String bookUuid) => isar.notes.filter().bookIdEqualTo(bookUuid).watch(fireImmediately: true);
  Future<void> updateNote(Note note) async { await isar.writeTxn(() async { await isar.notes.put(note); }); }
  Future<void> deleteNote(int id) async { await isar.writeTxn(() async { await isar.notes.delete(id); }); }
}
