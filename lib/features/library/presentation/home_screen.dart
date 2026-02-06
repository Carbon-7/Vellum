import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import 'upload_screen.dart';
import 'search_screen.dart';
import 'edit_book_dialog.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../reader/presentation/reader_screen.dart';
import '../../notes/presentation/book_notes_screen.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/storage_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../settings/data/settings_repository.dart';
import 'audiobook_player.dart';

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier(ref.read(storageServiceProvider));
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final StorageService _storage;
  FavoritesNotifier(this._storage) : super({}) { _load(); }
  
  Future<void> _load() async {
    final list = await _storage.getFavorites();
    state = list.toSet();
  }
  
  Future<void> toggle(String uuid) async {
    await _storage.toggleFavorite(uuid);
    await _load();
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Ensure consistent background
      body: StreamBuilder<List<Book>>(
        stream: ref.watch(bookRepositoryProvider).watchBooks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final books = snapshot.data ?? [];

          // Determine "Continue Reading" (Sort by lastReadTime)
          final continueReadingBooks = books.where((b) => b.lastReadPosition > 0).toList();
          continueReadingBooks.sort((a, b) => (b.lastReadTime ?? b.createdAt).compareTo(a.lastReadTime ?? a.createdAt));
          
          final featuredBook = continueReadingBooks.isNotEmpty ? continueReadingBooks.first : (books.isNotEmpty ? books.last : null);

          // Extract unique genres
          final genres = <String>{'All'};
          final favs = ref.watch(favoritesProvider);
          bool hasFavs = false;
          
          for (final book in books) {
            genres.add(book.genre);
            if(favs.contains(book.uuid)) hasFavs = true;
          }
          if(hasFavs) genres.add('Favourites');
          
          final genreList = genres.toList()..sort((a,b) {
            if(a == 'All') return -1;
            if(b == 'All') return 1;
            if(a == 'Favourites') return -1;
            if(b == 'Favourites') return 1;
            return a.compareTo(b);
          });

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Minimalistic AppBar
              SliverAppBar(
                floating: true,
                pinned: true,
                expandedHeight: 120,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  expandedTitleScale: 1.2,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
                  title: Text(
                    'My Library', 
                    style: GoogleFonts.libreBaskerville(
                       color: theme.colorScheme.onSurface, 
                       fontWeight: FontWeight.bold
                    )
                  ),
                ),
                actions: [
                  IconButton(icon: Icon(LucideIcons.search, color: theme.colorScheme.onSurface), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SearchScreen()))),
                  IconButton(icon: Icon(LucideIcons.settings, color: theme.colorScheme.onSurface), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsScreen()))),
                  const SizedBox(width: 16),
                ],
              ),
              
              if (books.isEmpty)
                SliverFillRemaining(
                   hasScrollBody: false,
                   child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.library, size: 64, color: theme.colorScheme.secondary.withOpacity(0.5)),
                        ),
                        const SizedBox(height: 32),
                        Text('Your Library is Empty', style: GoogleFonts.libreBaskerville(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text('Import your first book to get started', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const UploadScreen())),
                          icon: const Icon(LucideIcons.bookUp),
                          label: const Text('Import Books'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            backgroundColor: theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        )
                      ],
                    ),
                   ),
                ),

              if (books.isNotEmpty && featuredBook != null) ...[
                 SliverToBoxAdapter(
                   child: Padding(
                     padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                             Icon(LucideIcons.sparkles, size: 16, color: theme.colorScheme.secondary),
                             const SizedBox(width: 8),
                             Text(continueReadingBooks.isNotEmpty ? 'CONTINUE READING' : 'RECENTLY ADDED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: theme.colorScheme.secondary)),
                           ],
                         ),
                         const SizedBox(height: 16),
                         _HeroBookCard(book: featuredBook),
                       ],
                     ),
                   ),
                 ),
                 
                 // Genre Chips
                 SliverToBoxAdapter(
                   child: SizedBox(
                     height: 48,
                     child: ListView.separated(
                       physics: const BouncingScrollPhysics(),
                       padding: const EdgeInsets.symmetric(horizontal: 20),
                       scrollDirection: Axis.horizontal,
                       itemCount: genreList.length,
                       separatorBuilder: (c, i) => const SizedBox(width: 10),
                       itemBuilder: (context, index) {
                         final genre = genreList[index];
                         final isSelected = index == 0;
                         return GestureDetector(
                           onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => GenreBookListScreen(genre: genre == 'All' ? null : genre))),
                           child: AnimatedContainer(
                             duration: const Duration(milliseconds: 200),
                             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                             alignment: Alignment.center,
                             decoration: BoxDecoration(
                               color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
                               borderRadius: BorderRadius.circular(24),
                               border: Border.all(color: isSelected ? Colors.transparent : theme.colorScheme.outlineVariant),
                             ),
                             child: Text(
                               genre,
                               style: TextStyle(
                                 color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                 fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                               ),
                             ),
                           ),
                         );
                       },
                     ),
                   ),
                 ),
                 
                 const SliverToBoxAdapter(child: SizedBox(height: 24)),

                 SliverPadding(
                   padding: const EdgeInsets.symmetric(horizontal: 20),
                   sliver: SliverGrid(
                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 2,
                       childAspectRatio: 0.68,
                       crossAxisSpacing: 20,
                       mainAxisSpacing: 20,
                     ),
                     delegate: SliverChildBuilderDelegate(
                       (context, index) => _BookCard(book: books[index]),
                       childCount: books.length,
                     ),
                   ),
                 ),
              ],
              
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const UploadScreen())),
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        elevation: 4,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Book'),
      ),
    );
  }
}

class _HeroBookCard extends StatelessWidget {
  final Book book;
  const _HeroBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(isScrollControlled: true, context: context, backgroundColor: Colors.transparent, builder: (context) => _BookDetailsSheet(book: book)),
      child: Container(
        height: 200, // Slightly taller for better proportions
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06), 
              blurRadius: 24, 
              offset: const Offset(0, 8)
            )
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: 'hero_cover_${book.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                child: Container(
                  width: 130,
                  color: Color(int.parse((book.coverColor ?? '#795548').replaceFirst('#', '0xFF'))),
                  child: book.coverUrl != null 
                    ? CachedNetworkImage(imageUrl: book.coverUrl!, fit: BoxFit.cover, height: double.infinity) 
                    : Center(child: Icon(LucideIcons.book, size: 40, color: Colors.white.withOpacity(0.8))),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6)
                      ),
                      child: Text(book.genre.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                    const SizedBox(height: 12),
                    Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.libreBaskerville(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2)),
                    const SizedBox(height: 8),
                    Text(book.author, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 14)),
                    const Spacer(),
                    if (book.lastReadPosition > 0 && book.totalPages > 0) ...[
                      Row(
                        children: [
                          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: book.lastReadPosition / book.totalPages, minHeight: 6, backgroundColor: Theme.of(context).colorScheme.surfaceVariant))),
                          const SizedBox(width: 8),
                          Text('${(book.lastReadPosition / book.totalPages * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ] else 
                      Row(
                        children: [
                          Icon(LucideIcons.playCircle, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text('Start Reading', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCard extends ConsumerWidget {
  final Book book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).contains(book.uuid);
    return GestureDetector(
      onTap: () => showModalBottomSheet(isScrollControlled: true, context: context, backgroundColor: Colors.transparent, builder: (context) => _BookDetailsSheet(book: book)),
      onLongPress: () => _showOptions(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Color(int.parse((book.coverColor ?? '#795548').replaceFirst('#', '0xFF'))),
                    child: book.coverUrl != null ? CachedNetworkImage(imageUrl: book.coverUrl!, fit: BoxFit.cover) : Center(child: Icon(LucideIcons.book, color: Colors.white.withOpacity(0.7), size: 32)),
                  ),
                  Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), child: Text(book.genre, style: const TextStyle(color: Colors.white, fontSize: 10)))),
                  Positioned(
                    top: 8, right: 8, 
                    child: GestureDetector(
                      onTap: () => ref.read(favoritesProvider.notifier).toggle(book.uuid),
                      child: Container(
                        padding: const EdgeInsets.all(6), 
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), 
                        child: Icon(isFav ? LucideIcons.heart : LucideIcons.heart, size: 16, color: isFav ? Colors.red : Colors.grey)
                      ),
                    )
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                     const Spacer(),
                     Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                   ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
  
  void _showOptions(BuildContext context, WidgetRef ref) {
     showModalBottomSheet(context: context, builder: (context) => Container(padding: const EdgeInsets.symmetric(vertical: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(LucideIcons.edit), title: const Text('Edit Details'), onTap: () { Navigator.pop(context); showDialog(context: context, builder: (context) => EditBookDialog(book: book)); }),
        ListTile(leading: const Icon(LucideIcons.trash2, color: Colors.red), title: const Text('Delete Book', style: TextStyle(color: Colors.red)), onTap: () async { Navigator.pop(context); final c = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete Book?'), content: Text('Delete "${book.title}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))])); if (c == true) ref.read(bookRepositoryProvider).deleteBook(book.id); }),
     ])));
  }
}


class GenreBookListScreen extends ConsumerStatefulWidget {
  final String? genre;
  const GenreBookListScreen({super.key, this.genre});

  @override
  ConsumerState<GenreBookListScreen> createState() => _GenreBookListScreenState();
}

class _GenreBookListScreenState extends ConsumerState<GenreBookListScreen> {
  String _searchQuery = '';
  String _sortBy = 'Title'; // Title, Author, Recent

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchQuery.isEmpty 
             ? Text(widget.genre ?? 'All Books', style: GoogleFonts.libreBaskerville(fontWeight: FontWeight.bold)) 
             : TextField(
                 autofocus: true,
                 style: Theme.of(context).textTheme.titleLarge,
                 decoration: InputDecoration(
                   hintText: 'Search in genre...', 
                   border: InputBorder.none,
                   focusedBorder: InputBorder.none,
                   enabledBorder: InputBorder.none,
                   hintStyle: TextStyle(color: Theme.of(context).hintColor),
                 ),
                 onChanged: (v) => setState(() => _searchQuery = v),
               ),
        backgroundColor: Colors.transparent,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_searchQuery.isEmpty ? LucideIcons.search : LucideIcons.x),
            onPressed: () {
               setState(() {
                 if (_searchQuery.isNotEmpty) _searchQuery = '';
                 else _searchQuery = ' '; // Trigger search mode
               });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.arrowUpDown),
             color: Theme.of(context).cardTheme.color,
             surfaceTintColor: Theme.of(context).cardTheme.surfaceTintColor,
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (c) => ['Title', 'Author', 'Recent'].map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
          ),
        ],
      ),
      body: StreamBuilder<List<Book>>(
        stream: ref.watch(bookRepositoryProvider).watchBooks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var all = snapshot.data!;
          
          // Filter by Genre
          if (widget.genre != null) {
            if (widget.genre == 'Favourites') {
               final favs = ref.watch(favoritesProvider);
               all = all.where((b) => favs.contains(b.uuid)).toList();
            } else {
               all = all.where((b) => b.genre == widget.genre).toList();
            }
          }
          
          // Filter by Search
          if (_searchQuery.trim().isNotEmpty) {
             final q = _searchQuery.toLowerCase();
             all = all.where((b) => b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q)).toList();
          }
          
          // Sort
          all.sort((a,b) {
             switch(_sortBy) {
               case 'Author': return a.author.compareTo(b.author);
               case 'Recent': return (b.createdAt).compareTo(a.createdAt);
               default: return a.title.compareTo(b.title);
             }
          });

          if(all.isEmpty) return const Center(child: Text('No books found'));

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: all.length,
            itemBuilder: (context, index) => _BookCard(book: all[index]),
          );
        },
      ),
    );
  }
}

// Re-using _BookDetailsSheet EXACTLY as before (to keep features safe)
class _BookDetailsSheet extends ConsumerStatefulWidget {
  final Book book;
  const _BookDetailsSheet({required this.book});
  @override
  ConsumerState<_BookDetailsSheet> createState() => _BookDetailsSheetState();
}

class _BookDetailsSheetState extends ConsumerState<_BookDetailsSheet> {
  bool _isGeneratingSummary = false;
  String _selectedLanguage = 'English';
  final List<String> _languages = ['English', 'Hindi', 'Spanish', 'French', 'German', 'Gujarati'];

  String _cleanText(String text) => text.replaceAll('**', '').replaceAll('##', '').replaceAll('*', '').trim();

  Future<void> _generateSummary(BuildContext context, {bool force = false}) async {
    // We only check cache if NOT forcing and language is English (default key). 
    // If language is custom, we might need a custom key like summary_uuid_lang.
    // For simplicity, we only cache English summaries or suffix key.
    
    final key = '${widget.book.uuid}_$_selectedLanguage';
    
    if (!force) {
      final existing = await ref.read(storageServiceProvider).getSummary(key); // Updated StorageService usage implicitly handled if we updated lookup. 
      // Wait, getSummary takes just uuid. I need to update StorageService or manage keys manually.
      // StorageService.getSummary uses 'summary_$bookUuid'. 
      // I'll assume we bypass cache for non-English OR I use force always for specific languages for now.
      // Actually, user wants regeneration to work.
      // Let's stick to force regeneration feature mainly.
      // If language is English, we check cache first.
      
       if (_selectedLanguage == 'English') {
          final existing = await ref.read(storageServiceProvider).getSummary(widget.book.uuid);
          if (existing != null && existing.isNotEmpty) {
             if(!mounted) return;
             Navigator.pop(context); 
             _showSummaryPanel(context, existing);
             return;
          }
       }
    }
    
    setState(() => _isGeneratingSummary = true);
    try {
      final rawSummary = await ref.read(aiServiceProvider).summarizeBook(widget.book.title, widget.book.author, language: _selectedLanguage);
      final cleanSummary = _cleanText(rawSummary);
      
      // Save only if English for now to keep simple cache, or update Key logic.
      if (_selectedLanguage == 'English') {
         await ref.read(storageServiceProvider).saveSummary(widget.book.uuid, cleanSummary);
      }
      
      if (!mounted) return;
      Navigator.pop(context); 
      _showSummaryPanel(context, cleanSummary);
    } catch (e) {
      if (!mounted) return;
      showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Error'), content: Text(e.toString()), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
    } finally {
      if (mounted) setState(() => _isGeneratingSummary = false);
    }
  }
  
  FlutterTts? _tts;
  bool _isPlaying = false;
  
  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _initTts();
  }
  
  void _initTts() async {
    await _tts?.setSharedInstance(true);
    final selectedVoice = ref.read(settingsRepositoryProvider).getTtsVoice();
    await _tts?.setVoice({"name": selectedVoice, "locale": "en-US"});
    await _tts?.setSpeechRate(0.5);
    await _tts?.setVolume(1.0);
    await _tts?.setPitch(1.0);
    _tts?.setCompletionHandler(() {
       if(mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _tts?.stop();
    super.dispose();
  }

  void _speak(String text) async {
     if (_isPlaying) {
       await _tts?.stop();
       setState(() => _isPlaying = false);
     } else {
       setState(() => _isPlaying = true);
       await _tts?.speak(text);
     }
  }

  void _showSummaryPanel(BuildContext context, String summary) {
     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       backgroundColor: Theme.of(context).colorScheme.surface,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
       builder: (context) => StatefulBuilder( // Use StatefulBuilder to update Play icon
         builder: (context, setSheetState) => DraggableScrollableSheet(
           initialChildSize: 0.6,
           minChildSize: 0.4,
           maxChildSize: 0.9,
           expand: false,
           builder: (context, controller) => Padding(
             padding: const EdgeInsets.all(24),
             child: ListView(
               controller: controller,
               children: [
                 Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
                 const SizedBox(height: 20),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text('Summary ($_selectedLanguage)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                     IconButton(
                       icon: Icon(_isPlaying ? LucideIcons.stopCircle : LucideIcons.volume2, color: _isPlaying ? Colors.red : Colors.blue),
                       onPressed: () {
                          _speak(summary);
                          setSheetState(() {}); // Update local icon state
                       },
                     )
                   ],
                 ),
                 const SizedBox(height: 16),
                 Text(summary, style: const TextStyle(fontSize: 16, height: 1.6)),
                 const SizedBox(height: 24),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                     TextButton.icon(
                       icon: const Icon(LucideIcons.refreshCcw, size: 16), 
                       label: const Text('Regenerate'), 
                       onPressed: () { _tts?.stop(); Navigator.pop(context); _generateSummary(context, force: true); }
                     ),
                     const SizedBox(width: 16),
                     FilledButton(onPressed: () { _tts?.stop(); Navigator.pop(context); }, child: const Text('Done')),
                   ],
                 )
               ],
             ),
           ),
         ),
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = widget.book;
    
    // Check if user has started listening (placeholder - will be implemented with storage)
    final hasStartedListening = false; // TODO: Get from storage
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      height: MediaQuery.of(context).size.height * 0.75, // Taller sheet for better view
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(children: [
                Hero(tag: 'cover_${book.id}', child: Container(width: 90, height: 135, decoration: BoxDecoration(color: Color(int.parse((book.coverColor ?? '#795548').replaceFirst('#', '0xFF'))), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)], image: book.coverUrl != null ? DecorationImage(image: CachedNetworkImageProvider(book.coverUrl!), fit: BoxFit.cover) : null), child: book.coverUrl == null ? Center(child: Icon(LucideIcons.book, size: 40, color: Colors.white.withOpacity(0.7))) : null)),
                const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(book.title, style: theme.textTheme.headlineSmall?.copyWith(fontFamily: GoogleFonts.libreBaskerville().fontFamily, fontWeight: FontWeight.bold), maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Text(book.author, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                    const SizedBox(height: 8),
                    Chip(label: Text(book.genre), backgroundColor: theme.colorScheme.primaryContainer, labelStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 12), visualDensity: VisualDensity.compact),
                ])),
            ]),
            const SizedBox(height: 32),
            if (book.lastReadPosition > 0 && book.totalPages > 0) ...[
               Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${(book.lastReadPosition / book.totalPages * 100).toInt()}% Read', style: const TextStyle(fontWeight: FontWeight.bold)), Text('${book.lastReadPosition + 1} of ${book.totalPages}')]),
               const SizedBox(height: 8),
               ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: book.lastReadPosition / book.totalPages, minHeight: 8)),
               const SizedBox(height: 24),
            ],
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderScreen(book: book))); }, icon: const Icon(LucideIcons.bookOpen), label: Text(book.lastReadPosition > 0 ? 'Continue Reading' : 'Read Now'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                   showDialog(
                     context: context,
                     builder: (context) => AlertDialog(
                       backgroundColor: theme.colorScheme.surface,
                       surfaceTintColor: theme.colorScheme.surface,
                       title: Row(
                         children: [
                           Icon(LucideIcons.sparkles, color: theme.colorScheme.secondary),
                           const SizedBox(width: 8),
                           const Text('Coming Soon'),
                         ],
                       ),
                       content: const Text(
                         'The Audiobook experience is getting a major upgrade!\n\nWe are crafting a more immersive listening experience for you. Stay tuned for the next update.',
                         style: TextStyle(fontSize: 16, height: 1.5),
                       ),
                       actions: [
                         TextButton(
                           onPressed: () => Navigator.pop(context),
                           child: const Text('Can\'t Wait!'),
                         ),
                       ],
                     ),
                   );
                },
                icon: const Icon(LucideIcons.headphones),
                label: const Text('Listen (Coming Next Update)'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.5), // Dimmed to indicate disabled/future
                  foregroundColor: theme.colorScheme.onSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => BookNotesScreen(book: book))); }, icon: const Icon(LucideIcons.stickyNote), label: const Text('Notes'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(
                  onPressed: _isGeneratingSummary ? null : () => _showInternalLanguageDialog(context),
                  icon: _isGeneratingSummary ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.sparkles), 
                  label: Text(_isGeneratingSummary ? 'Thinking...' : 'Summary'), 
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16))
                )),
            ]),
            const SizedBox(height: 24),
        ]),
      ),
    );
  }

  void _showInternalLanguageDialog(BuildContext context) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Select Language'),
      content: DropdownButtonFormField<String>(
        value: _selectedLanguage,
        items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
        onChanged: (v) { _selectedLanguage = v!; Navigator.pop(context); _generateSummary(context); },
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))]
    ));
  }
}
