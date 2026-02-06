import 'package:isar/isar.dart';

part 'book.g.dart';

@collection
class Book {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  late String title;
  late String author;
  late String filePath;
  
  @Index()
  String genre = 'General';
  
  String? coverColor;
  String? coverUrl;
  int lastReadPosition = 0;
  int totalPages = 0;
  DateTime? lastReadTime;
  late DateTime createdAt;

  Book() {
    createdAt = DateTime.now();
    // Assign random earth-tone color if not provided
    if (coverColor == null) {
      final colors = [
        '#8D6E63',
        '#5D4037',
        '#795548',
        '#6D4C41',
        '#4E342E',
        '#A1887F',
        '#BCAAA4',
        '#8B7355',
        '#7B6B5D',
        '#9E8B7E',
      ];
      coverColor = colors[DateTime.now().millisecondsSinceEpoch % colors.length];
    }
  }
}
