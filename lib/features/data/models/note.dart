import 'package:isar/isar.dart';

part 'note.g.dart';

@collection
class Note {
  Id id = Isar.autoIncrement;

  @Index()
  late String bookId; // Links to Book UUID

  late String highlight;
  String comment = '';
  String title = '';
  String subtitle = '';
  
  // Styling
  String color = '0xFFFFF9C4'; // Default pastel yellow
  bool isBold = false;
  bool isItalic = false;
  double fontSize = 16.0;
  String fontFamily = 'Kalam';

  late DateTime createdAt;

  Note() {
    createdAt = DateTime.now();
  }
}
// Trigger build runner update
