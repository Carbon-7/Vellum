import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../reader/presentation/reader_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  int _sortIndex = 0; // 0: Relevance, 1: Newest, 2: Oldest, 3: A-Z
  bool _onlyMyList = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _showSortOptions() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context, 
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text('Sort By', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(title: const Text('Relevance'), trailing: _sortIndex == 0 ? Icon(LucideIcons.check, color: theme.colorScheme.primary) : null, onTap: () { setState(() => _sortIndex = 0); Navigator.pop(context); }),
            ListTile(title: const Text('Date Added (Newest)'), trailing: _sortIndex == 1 ? Icon(LucideIcons.check, color: theme.colorScheme.primary) : null, onTap: () { setState(() => _sortIndex = 1); Navigator.pop(context); }),
            ListTile(title: const Text('Date Added (Oldest)'), trailing: _sortIndex == 2 ? Icon(LucideIcons.check, color: theme.colorScheme.primary) : null, onTap: () { setState(() => _sortIndex = 2); Navigator.pop(context); }),
            ListTile(title: const Text('Title (A-Z)'), trailing: _sortIndex == 3 ? Icon(LucideIcons.check, color: theme.colorScheme.primary) : null, onTap: () { setState(() => _sortIndex = 3); Navigator.pop(context); }),
            const SizedBox(height: 16),
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search title, author, or genre...',
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            filled: false,
          ),
          style: theme.textTheme.bodyLarge,
          onChanged: (value) {
            setState(() {
              _query = value.toLowerCase();
            });
          },
        ),
        actions: [
          IconButton(icon: Icon(LucideIcons.listFilter, color: theme.colorScheme.onSurface), onPressed: _showSortOptions),
          if (_query.isNotEmpty)
            IconButton(
              icon: Icon(LucideIcons.x, color: theme.colorScheme.onSurface),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('My Reading List'),
              selected: _onlyMyList,
              onSelected: (v) => setState(() => _onlyMyList = v),
              showCheckmark: false,
              avatar: _onlyMyList ? const Icon(LucideIcons.check, size: 14) : null,
              backgroundColor: theme.colorScheme.surface,
              selectedColor: theme.colorScheme.primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: _onlyMyList ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                fontWeight: _onlyMyList ? FontWeight.bold : FontWeight.normal
              ),
              side: BorderSide(color: _onlyMyList ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.5)),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Book>>(
        stream: ref.watch(bookRepositoryProvider).watchBooks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No books in library', style: theme.textTheme.bodyLarge));
          }

          var books = snapshot.data!;
          
          // 1. Filter by List Status
          if (_onlyMyList) {
             books = books.where((b) => b.lastReadPosition > 0).toList();
          }

          // 2. Filter by Query
          if (_query.isNotEmpty) {
             books = books.where((book) {
               return book.title.toLowerCase().contains(_query) ||
                   book.author.toLowerCase().contains(_query) ||
                   book.genre.toLowerCase().contains(_query);
             }).toList();
          }
          
          // 3. Sort
          switch(_sortIndex) {
            case 1: books.sort((a,b) => b.createdAt.compareTo(a.createdAt)); break;
            case 2: books.sort((a,b) => a.createdAt.compareTo(b.createdAt)); break;
            case 3: books.sort((a,b) => a.title.compareTo(b.title)); break;
            default: // Relevance (approx. matches startsWith first)
               if (_query.isNotEmpty) {
                 books.sort((a, b) {
                    bool aStarts = a.title.toLowerCase().startsWith(_query);
                    bool bStarts = b.title.toLowerCase().startsWith(_query);
                    if (aStarts && !bStarts) return -1;
                    if (!aStarts && bStarts) return 1;
                    return 0;
                 });
               }
               break;
          }

          if (books.isEmpty && _query.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.searchX, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No matches found', style: theme.textTheme.headlineSmall),
                ],
              ),
            );
          }
          
          if (_query.isEmpty && !_onlyMyList) {
             return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.search, size: 64, color: theme.colorScheme.outline.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Search your library', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
                leading: Container(
                  width: 48,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Color(int.parse(book.coverColor!.replaceFirst('#', '0xFF'))),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                    image: book.coverUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(book.coverUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: book.coverUrl == null
                      ? const Icon(LucideIcons.book, color: Colors.white54, size: 24)
                      : null,
                ),
                title: Text(book.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(book.author, style: theme.textTheme.bodyMedium, maxLines: 1),
                    const SizedBox(height: 4),
                    Row(
                       children: [
                         Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(4)), child: Text(book.genre, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant))),
                         if (book.lastReadPosition > 0) ...[
                            const SizedBox(width: 8),
                            Text('${(book.lastReadPosition / (book.totalPages == 0 ? 1 : book.totalPages) * 100).toInt()}%', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary))
                         ]
                       ],
                    )
                  ],
                ),
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderScreen(book: book)));
                },
              );
            },
          );
        },
      ),
    );
  }
}
