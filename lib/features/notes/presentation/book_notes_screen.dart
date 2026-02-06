import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../data/models/book.dart';
import '../../data/models/note.dart';
import '../../data/repositories/book_repository.dart';
import '../../../core/services/storage_service.dart';

class BookNotesScreen extends ConsumerWidget {
  final Book book;

  const BookNotesScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Notes: ${book.title}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context, ref, null),
        child: const Icon(LucideIcons.plus),
      ),
      body: StreamBuilder<List<Note>>(
        stream: ref.watch(bookRepositoryProvider).watchNotesForBook(book.uuid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.stickyNote, size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No notes yet. Tap + to add one!'),
                ],
              ),
            );
          }
          final notes = snapshot.data!;
          return MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            padding: const EdgeInsets.all(12),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return _StickyNoteCard(
                note: note,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NoteDetailScreen(note: note))),
                onDelete: () => ref.read(bookRepositoryProvider).deleteNote(note.id),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditor(BuildContext context, WidgetRef ref, Note? existingNote) async {
    Color initialTextColor = Colors.black;
    if (existingNote != null) {
      final code = await ref.read(storageServiceProvider).getNoteTextColor(existingNote.id);
      initialTextColor = Color(int.parse(code));
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StickyNoteEditorDialog(
        initialNote: existingNote,
        initialTextColor: initialTextColor,
        onSave: (title, subtitle, text, color, textColor, isBold, isItalic, fontSize, font) async {
          Note savedNote;
          if (existingNote == null) {
            savedNote = await ref.read(bookRepositoryProvider).addNote(
              bookId: book.uuid,
              highlight: text,
              title: title,
              subtitle: subtitle,
              color: '0x${color.value.toRadixString(16).toUpperCase()}',
              isBold: isBold,
              isItalic: isItalic,
              fontSize: fontSize,
              fontFamily: font,
            );
          } else {
            existingNote.highlight = text;
            existingNote.title = title;
            existingNote.subtitle = subtitle;
            existingNote.color = '0x${color.value.toRadixString(16).toUpperCase()}';
            existingNote.isBold = isBold;
            existingNote.isItalic = isItalic;
            existingNote.fontSize = fontSize;
            existingNote.fontFamily = font;
            await ref.read(bookRepositoryProvider).updateNote(existingNote);
            savedNote = existingNote;
          }
          
          await ref.read(storageServiceProvider).saveNoteTextColor(
            savedNote.id,
            '0x${textColor.value.toRadixString(16).toUpperCase()}',
          );
        },
      ),
    );
  }
}

class NoteDetailScreen extends ConsumerWidget {
  final Note note;
  const NoteDetailScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color noteColor;
    try { noteColor = Color(int.parse(note.color)); } catch (_) { noteColor = const Color(0xFFFFF9C4); }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('View Note'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil),
            onPressed: () async {
              final code = await ref.read(storageServiceProvider).getNoteTextColor(note.id);
              final initialTextColor = Color(int.parse(code));
              
              if(!context.mounted) return;
              
              showDialog(
                context: context,
                builder: (context) => StickyNoteEditorDialog(
                  initialNote: note,
                  initialTextColor: initialTextColor,
                  onSave: (title, subtitle, text, color, textColor, isBold, isItalic, fontSize, font) async {
                    note.highlight = text;
                    note.title = title;
                    note.subtitle = subtitle;
                    note.color = '0x${color.value.toRadixString(16).toUpperCase()}';
                    note.isBold = isBold;
                    note.isItalic = isItalic;
                    note.fontSize = fontSize;
                    note.fontFamily = font;
                    
                    await ref.read(bookRepositoryProvider).updateNote(note);
                    await ref.read(storageServiceProvider).saveNoteTextColor(note.id, '0x${textColor.value.toRadixString(16).toUpperCase()}');
                    
                    Navigator.pop(context); // Close Dialog
                    Navigator.pop(context); // Close Detail
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: 'note_${note.id}',
          child: Material(
            color: Colors.transparent,
            child: FutureBuilder<String>(
              future: ref.read(storageServiceProvider).getNoteTextColor(note.id),
              builder: (context, snapshot) {
                 final textColor = snapshot.hasData ? Color(int.parse(snapshot.data!)) : Colors.black;
                 return Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(minHeight: 300),
                  decoration: BoxDecoration(color: noteColor, borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (note.title.isNotEmpty) Text(note.title, style: GoogleFonts.getFont(note.fontFamily.isEmpty ? 'Kalam' : note.fontFamily, fontSize: note.fontSize + 8, fontWeight: FontWeight.bold, color: textColor)),
                        if (note.subtitle.isNotEmpty) Text(note.subtitle, style: GoogleFonts.getFont(note.fontFamily.isEmpty ? 'Kalam' : note.fontFamily, fontSize: note.fontSize + 2, fontStyle: FontStyle.italic, color: textColor.withOpacity(0.7))),
                        const SizedBox(height: 8),
                        Text(note.highlight, style: GoogleFonts.getFont(note.fontFamily.isEmpty ? 'Kalam' : note.fontFamily, fontSize: note.fontSize, fontWeight: note.isBold ? FontWeight.bold : FontWeight.normal, fontStyle: note.isItalic ? FontStyle.italic : FontStyle.normal, color: textColor))
                    ]),
                  ),
                );
              }
            ),
          ),
        ),
      ),
    );
  }
}

class StickyNoteEditorDialog extends StatefulWidget {
  final Note? initialNote;
  final Color initialTextColor;
  final Function(String title, String subtitle, String text, Color color, Color textColor, bool isBold, bool isItalic, double fontSize, String fontFamily) onSave;

  const StickyNoteEditorDialog({super.key, this.initialNote, required this.onSave, this.initialTextColor = Colors.black});

  @override
  State<StickyNoteEditorDialog> createState() => _StickyNoteEditorDialogState();
}

class _StickyNoteEditorDialogState extends State<StickyNoteEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _textController;
  late Color _selectedColor;
  late Color _selectedTextColor;
  bool _editingTextColor = false;

  late bool _isBold;
  late bool _isItalic;
  late double _fontSize;
  late String _fontFamily;

  final List<String> _fonts = const ['Kalam', 'Roboto', 'Merriweather', 'Lato', 'Oswald', 'Dancing Script'];
  final List<Color> _colors = const [
     Color(0xFFFFF9C4), Color(0xFFFFCCBC), Color(0xFFC8E6C9), Color(0xFFB3E5FC),
     Color(0xFFE1BEE7), Color(0xFFF5F5F5), Color(0xFFFFCDD2), Color(0xFFCFD8DC),
     Colors.white, Colors.black, Colors.grey, Colors.blueGrey
  ];

  @override
  void initState() {
    super.initState();
    final n = widget.initialNote;
    _titleController = TextEditingController(text: n?.title ?? '');
    _subtitleController = TextEditingController(text: n?.subtitle ?? '');
    _textController = TextEditingController(text: n?.highlight ?? '');
    try { _selectedColor = n != null ? Color(int.parse(n.color)) : const Color(0xFFFFF9C4); } catch (_) { _selectedColor = const Color(0xFFFFF9C4); }
    _selectedTextColor = widget.initialTextColor;
    
    _isBold = n?.isBold ?? false;
    _isItalic = n?.isItalic ?? false;
    _fontSize = n?.fontSize ?? 18.0;
    _fontFamily = (n?.fontFamily == null || n!.fontFamily.isEmpty) ? 'Kalam' : n.fontFamily;
  }

  void _addBullet() {
    final selection = _textController.selection;
    final newText = _textController.text.replaceRange(selection.start, selection.end, '\n• ');
    _textController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: selection.start + 3));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center, // Align to center
        children: [
          // Glass Interface
          ClipRRect(
             borderRadius: BorderRadius.circular(24),
             child: BackdropFilter(
               filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
               child: Container(
                 constraints: const BoxConstraints(maxWidth: 500),
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                   color: theme.colorScheme.surface.withOpacity(0.85),
                   borderRadius: BorderRadius.circular(24),
                   border: Border.all(color: Colors.white.withOpacity(0.1)),
                   boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
                 ),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.initialNote == null ? 'New Note' : 'Edit Note', 
                            style: GoogleFonts.libreBaskerville(fontSize: 20, fontWeight: FontWeight.bold)
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.check, color: Colors.green), 
                            onPressed: _save,
                            style: IconButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.1)),
                          ),
                       ],
                      ),
                      const Divider(height: 32),
                      
                      // Toolbar (Scrollable)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                             // Font Styles
                             Container(
                               padding: const EdgeInsets.all(4),
                               decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                               child: ToggleButtons(
                                 constraints: const BoxConstraints(minHeight: 36, minWidth: 36), 
                                 isSelected: [_isBold, _isItalic], 
                                 borderRadius: BorderRadius.circular(8),
                                 fillColor: theme.colorScheme.primary, // Active background
                                 selectedColor: theme.colorScheme.onPrimary, // Active icon
                                 color: theme.colorScheme.onSurface, // Inactive icon
                                 onPressed: (i) => setState(() { if(i==0)_isBold=!_isBold; else _isItalic=!_isItalic; }), 
                                 children: const [Icon(LucideIcons.bold, size: 18), Icon(LucideIcons.italic, size: 18)]
                               ),
                             ),
                             const SizedBox(width: 8),
                             
                             // List & Size
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                               decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                               child: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   IconButton(icon: const Icon(LucideIcons.list, size: 18), onPressed: _addBullet, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
                                   const SizedBox(width: 4),
                                   IconButton(icon: const Icon(LucideIcons.minus, size: 16), onPressed: () => setState(() => _fontSize = (_fontSize - 2).clamp(10, 40)), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                                   Text('${_fontSize.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)), 
                                   IconButton(icon: const Icon(LucideIcons.plus, size: 16), onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(10, 40)), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                                 ],
                               ),
                             ),
                             const SizedBox(width: 8),
                             
                             // Font Family
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12),
                               height: 44,
                               decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                               child: DropdownButtonHideUnderline(
                                 child: DropdownButton<String>(
                                   value: _fontFamily, 
                                   isDense: true, 
                                   icon: const Icon(LucideIcons.chevronDown, size: 16),
                                   items: _fonts.map((f) => DropdownMenuItem(value: f, child: Text(f, style: GoogleFonts.getFont(f, fontSize: 14)))).toList(), 
                                   onChanged: (v) => setState(() => _fontFamily = v!)
                                 ),
                               ),
                             ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Color Tabs
                      Row(
                         children: [
                           _TabButton(label: 'Background', isSelected: !_editingTextColor, onTap: () => setState(() => _editingTextColor = false)),
                           const SizedBox(width: 8),
                           _TabButton(label: 'Text Color', isSelected: _editingTextColor, onTap: () => setState(() => _editingTextColor = true)),
                         ],
                      ),
                      
                      // Color Palette
                      Padding(
                        padding: const EdgeInsets.only(top: 12), 
                        child: SizedBox(
                          height: 40, 
                          child: ListView(
                            scrollDirection: Axis.horizontal, 
                            children: _colors.map((c) {
                              final isActive = _editingTextColor ? _selectedTextColor == c : _selectedColor == c;
                              return GestureDetector(
                                onTap: () => setState(() => _editingTextColor ? _selectedTextColor = c : _selectedColor = c),
                                child: Container(
                                  width: 32, 
                                  height: 32, 
                                  margin: const EdgeInsets.only(right: 12), 
                                  decoration: BoxDecoration(
                                    color: c, 
                                    shape: BoxShape.circle, 
                                    border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1), 
                                    boxShadow: isActive ? [BoxShadow(color: theme.shadowColor.withOpacity(0.2), blurRadius: 4, spreadRadius: 1)] : null
                                  ), 
                                  child: isActive ? Icon(LucideIcons.check, size: 16, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null
                                )
                              );
                           }).toList()
                          )
                        )
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Note Preview / Editor
                      Expanded( // Allow growing
                         child: SingleChildScrollView(
                           child: Container(
                             width: double.infinity,
                             padding: const EdgeInsets.all(24),
                             decoration: BoxDecoration(
                               color: _selectedColor, 
                               borderRadius: BorderRadius.circular(16), 
                               boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                             ),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 TextField(
                                   controller: _titleController, 
                                   style: GoogleFonts.getFont(_fontFamily, fontSize: 20, fontWeight: FontWeight.bold, color: _selectedTextColor), 
                                   decoration: InputDecoration(
                                     hintText: 'Title', 
                                     border: InputBorder.none, 
                                     hintStyle: TextStyle(color: _selectedTextColor.withOpacity(0.5))
                                   )
                                 ),
                                 TextField(
                                   controller: _subtitleController, 
                                   style: GoogleFonts.getFont(_fontFamily, fontSize: 14, fontStyle: FontStyle.italic, color: _selectedTextColor.withOpacity(0.7)), 
                                   decoration: InputDecoration(
                                     hintText: 'Subtitle (optional)', 
                                     border: InputBorder.none,
                                     isDense: true,
                                     hintStyle: TextStyle(color: _selectedTextColor.withOpacity(0.4))
                                   )
                                 ),
                                 const Divider(color: Colors.black12, height: 20),
                                 TextField(
                                   controller: _textController, 
                                   maxLines: null, 
                                   style: GoogleFonts.getFont(_fontFamily, fontSize: _fontSize, fontWeight: _isBold ? FontWeight.bold : FontWeight.normal, fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal, color: _selectedTextColor), 
                                   decoration: InputDecoration(
                                     hintText: 'Write your thoughts...', 
                                     border: InputBorder.none,
                                     hintStyle: TextStyle(color: _selectedTextColor.withOpacity(0.5))
                                   )
                                 ),
                               ],
                             ),
                           ),
                         ),
                      ),
                   ],
                 ),
               ),
             ),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_textController.text.isNotEmpty || _titleController.text.isNotEmpty) {
      widget.onSave(_titleController.text, _subtitleController.text, _textController.text, _selectedColor, _selectedTextColor, _isBold, _isItalic, _fontSize, _fontFamily);
      Navigator.pop(context);
    }
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12
          )
        ),
      ),
    );
  }
}

class _StickyNoteCard extends ConsumerWidget {
  final Note note;
  final VoidCallback onTap, onDelete;
  const _StickyNoteCard({required this.note, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color cardColor;
    try { cardColor = Color(int.parse(note.color)); } catch (_) { cardColor = const Color(0xFFFFF9C4); }
    
    return FutureBuilder<String>(
      future: ref.read(storageServiceProvider).getNoteTextColor(note.id),
      builder: (context, snapshot) {
         final textColor = snapshot.hasData ? Color(int.parse(snapshot.data!)) : Colors.black;
         return GestureDetector(
          onTap: onTap,
          child: Hero(
            tag: 'note_${note.id}',
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(2, 2))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                   if (note.title.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(note.title, style: GoogleFonts.getFont(note.fontFamily.isEmpty ? 'Kalam' : note.fontFamily, fontSize: note.fontSize + 2, fontWeight: FontWeight.bold, color: textColor), maxLines: 1)),
                   Text(note.highlight, maxLines: 6, style: GoogleFonts.getFont(note.fontFamily.isEmpty ? 'Kalam' : note.fontFamily, fontSize: note.fontSize, fontWeight: note.isBold ? FontWeight.bold : FontWeight.normal, fontStyle: note.isItalic ? FontStyle.italic : FontStyle.normal, color: textColor)),
                   const SizedBox(height: 12),
                   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Icon(LucideIcons.stickyNote, size: 12, color: textColor.withOpacity(0.3)),
                      GestureDetector(onTap: onDelete, child: const Icon(LucideIcons.trash2, size: 16, color: Colors.black45))
                   ])
                ]),
              ),
            ),
          ),
        );
      }
    );
  }
}
