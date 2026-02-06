import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../data/models/book.dart';
import '../../data/models/note.dart';
import '../../data/repositories/book_repository.dart';
import '../../../core/services/ai_service.dart';
import '../../notes/presentation/book_notes_screen.dart';
import '../../../core/services/storage_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../settings/data/settings_repository.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late PDFViewController _pdfViewController;
  int _currentPage = 0; // Added for page tracking
  bool _isNightMode = false; // Controls Reader Night Mode
  bool _isSelectionMode = false;
  final GlobalKey _captureKey = GlobalKey();
  
  Color _panelColor = Colors.blue;
  final List<Map<String, String>> _chatHistory = [];
  
  double _boxTop = 150;
  double _boxLeft = 50;
  double _boxWidth = 200;
  double _boxHeight = 100;

  File? _lastCaptureFile;
  
  FlutterTts? _tts;
  bool _isSpeaking = false;
  
  // PDF Reliability State
  bool _isFileValid = true;
  int _keyUniqueId = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.lastReadPosition;
    _checkFile();
    _loadPanelColor();
    _initTts();
  }

  Future<void> _checkFile() async {
     final file = File(widget.book.filePath);
     if (!await file.exists() || await file.length() == 0) {
        if(mounted) setState(() => _isFileValid = false);
     }
  }

  void _initTts() async {
    _tts = FlutterTts();
    
    // Configure for best quality Google voices
    await _tts?.setSharedInstance(true);
    
    // Get voice from settings
    final selectedVoice = ref.read(settingsRepositoryProvider).getTtsVoice();
    await _tts?.setVoice({"name": selectedVoice, "locale": "en-US"});
    
    // Set speech parameters
    await _tts?.setSpeechRate(0.5);
    await _tts?.setVolume(1.0);
    await _tts?.setPitch(1.0);
    
    _tts?.setCompletionHandler(() {
      if(mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _tts?.stop();
    super.dispose();
  }

  Future<void> _loadPanelColor() async {
    final colorVal = await ref.read(storageServiceProvider).getPanelColor();
    setState(() => _panelColor = Color(colorVal));
  }

  bool _isFocusMode = false;

  @override
  Widget build(BuildContext context) {
    // If in night mode, we want a dark status bar, etc.
    // We use a Stack to overly controls on top of the PDF for an immersive feel.
    return Scaffold(
      backgroundColor: _isNightMode ? const Color(0xFF121212) : const Color(0xFFFDF8F0),
      body: SafeArea(
        top: !_isFocusMode,
        bottom: !_isFocusMode,
        child: Stack(
          children: [
            // 1. The Reader (PDF)
            // We use a Container to provide background color in case of transparency/corruption
            Container(
              color: _isNightMode ? const Color(0xFF121212) : const Color(0xFFFDF8F0),
              child: PDFView(
                key: ValueKey('pdf_view_${_isNightMode}_${_panelColor}_$_keyUniqueId'), // Unique ID allows force reload
                filePath: widget.book.filePath,
                enableSwipe: !_isSelectionMode,
                swipeHorizontal: true,
                autoSpacing: false,
                pageFling: true,
                pageSnap: true,
                defaultPage: _currentPage,
                nightMode: _isNightMode,
                onViewCreated: (c) => _pdfViewController = c,
                onPageChanged: (page, total) {
                   if (_isSpeaking) { _tts?.stop(); setState(() => _isSpeaking = false); }
                   setState(() => _currentPage = page!);
                   ref.read(bookRepositoryProvider).updateBookProgress(widget.book.id, page!, total ?? 0);
                },
                onError: (e) {
                  // Handle potential "corruption" visually
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error rendering page: $e')));
                },
              ),
            ),

            // 2. The Focus Mode Toggle (Always visible if UI hidden, or part of AppBar)
            if (_isFocusMode)
              Positioned(
                bottom: 30,
                right: 30,
                child: FloatingActionButton.small(
                  backgroundColor: _isNightMode ? Colors.grey[800] : Colors.white,
                  foregroundColor: _isNightMode ? Colors.white : Colors.black,
                  elevation: 4,
                  onPressed: () => setState(() => _isFocusMode = false),
                  child: const Icon(LucideIcons.minimize, size: 20),
                ),
              ),

            // 3. The Custom App Bar (Visible only when NOT in focus mode)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: _isFocusMode ? -100 : 0,
              left: 0,
              right: 0,
              child: _buildCustomAppBar(context),
            ),

            // 4. Selection Overlay
            if (_isSelectionMode) _buildSelectionBox(),
            
            // 5. Error Message (if file is invalid)
            if (!_isFileValid)
               Container(
                 color: Colors.black54,
                 child: Center(
                   child: Container(
                     padding: const EdgeInsets.all(20),
                     decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 40),
                         const SizedBox(height: 10),
                         const Text('Unable to load PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                         const Text('The file might be corrupted or missing.'),
                         const SizedBox(height: 10),
                         ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')) 
                       ],
                     ),
                   ),
                 ),
               ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
     final isDark = _isNightMode;
     final bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFDF8F0);
     final fgColor = isDark ? Colors.white : const Color(0xFF2D2D2D);

     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
       decoration: BoxDecoration(
          color: bgColor.withOpacity(0.95),
          boxShadow: [
             if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
       ),
       child: SafeArea(
         bottom: false,
         child: Row(
           children: [
             IconButton(
               icon: Icon(LucideIcons.arrowLeft, color: fgColor),
               onPressed: () => Navigator.pop(context),
             ),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Text(
                     widget.book.title, 
                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: fgColor, fontFamily: 'serif'), // Serif for reading feel
                     maxLines: 1, overflow: TextOverflow.ellipsis
                   ),
                   Text(
                     'Page ${_currentPage + 1}', 
                     style: TextStyle(fontSize: 12, color: fgColor.withOpacity(0.6))
                   ),
                 ],
               ),
             ),
             // Actions
             IconButton(
               icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon, color: fgColor), 
               tooltip: 'Toggle Theme',
               onPressed: () => setState(() => _isNightMode = !_isNightMode),
             ),
             IconButton(
               icon: Icon(_isFocusMode ? LucideIcons.minimize : LucideIcons.expand, color: fgColor),
               tooltip: 'Focus Mode',
               onPressed: () => setState(() => _isFocusMode = true),
             ),
             PopupMenuButton<String>(
               icon: Icon(LucideIcons.moreVertical, color: fgColor),
               color: bgColor,
               itemBuilder: (context) => [
                 PopupMenuItem(
                   child: Row(children: [Icon(LucideIcons.rotateCcw, size: 18, color: fgColor), const SizedBox(width: 8), Text('Reload PDF', style: TextStyle(color: fgColor))]),
                   onTap: () {
                      // Trigger a full rebuild of the PDFView key
                      setState(() { 
                        _keyUniqueId++; // We need to add this property state
                      });
                   },
                 ),
                 PopupMenuItem(
                   child: Row(children: [Icon(LucideIcons.crop, size: 18, color: fgColor), const SizedBox(width: 8), Text('Selection Mode', style: TextStyle(color: fgColor))]),
                   onTap: () => setState(() => _isSelectionMode = !_isSelectionMode),
                 ),
                 PopupMenuItem(
                   child: Row(children: [Icon(LucideIcons.messageCircle, size: 18, color: fgColor), const SizedBox(width: 8), Text('Chat with Author', style: TextStyle(color: fgColor))]),
                   onTap: _showChatPanel,
                 ),
                 PopupMenuItem(
                   child: Row(children: [Icon(LucideIcons.bot, size: 18, color: fgColor), const SizedBox(width: 8), Text('Ask AI', style: TextStyle(color: fgColor))]),
                   onTap: _showManualInput,
                 ),
                 PopupMenuItem(
                   child: Row(children: [Icon(_isSpeaking ? LucideIcons.stopCircle : LucideIcons.headphones, size: 18, color: _isSpeaking ? Colors.red : fgColor), const SizedBox(width: 8), Text(_isSpeaking ? 'Stop Reading' : 'Read Page', style: TextStyle(color: fgColor))]),
                   onTap: _toggleAiRead,
                 ),
               ]
             )
           ],
         ),
       ),
     );
  }

  Widget _buildSelectionBox() {
    return Positioned(
      top: _boxTop,
      left: _boxLeft,
      child: GestureDetector(
        onPanUpdate: (d) {
           setState(() {
             _boxTop += d.delta.dy;
             _boxLeft += d.delta.dx;
           });
        },
        child: Container(
          width: _boxWidth,
          height: _boxHeight,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blueAccent, width: 2),
            color: Colors.blueAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)
          ),
          child: Stack(
            children: [
               // Resize handle
               Positioned(
                 right: 0, bottom: 0,
                 child: GestureDetector(
                   onPanUpdate: (d) {
                      setState(() {
                        _boxWidth = (_boxWidth + d.delta.dx).clamp(50.0, 600.0);
                        _boxHeight = (_boxHeight + d.delta.dy).clamp(50.0, 600.0);
                      });
                   },
                   child: Container(
                     width: 30, height: 30,
                     decoration: const BoxDecoration(
                       color: Colors.blueAccent,
                       borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomRight: Radius.circular(4))
                     ),
                     child: const Icon(LucideIcons.moveDiagonal2, size: 16, color: Colors.white),
                   ),
                 ),
               ),
               // Analyze Button (Integrated into box for cleaner UI)
               Positioned(
                 right: 0, top: 0,
                 child: GestureDetector(
                   onTap: _analyzeSelection,
                   child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8), topRight: Radius.circular(4))),
                      child: const Icon(LucideIcons.sparkles, size: 16, color: Colors.white),
                   ),
                 )
               ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _analyzeSelection() async {
     try {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analyzing...')));
       
       RenderRepaintBoundary boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
       ui.Image image = await boundary.toImage(pixelRatio: 2.0);
       ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
       if (byteData == null) return;
       
       final tempDir = await getTemporaryDirectory();
       _lastCaptureFile = File('${tempDir.path}/capture_${DateTime.now().millisecondsSinceEpoch}.png');
       await _lastCaptureFile!.writeAsBytes(byteData.buffer.asUint8List());
       
       final extractedText = await ref.read(aiServiceProvider).extractTextFromImage(_lastCaptureFile!);
       
       if (extractedText.trim().isEmpty) {
          if(mounted) _showResultPanel("Analysis", "Visual Selection", "No text recognizable.", isError: true);
       } else {
          _processText(extractedText);
       }
     } catch (e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
     }
  }

  void _processText(String text) {
     int wordCount = text.split(RegExp(r'\s+')).length;
     if (wordCount <= 3 && wordCount > 0 && !text.contains('Diagram')) {
        _fetchMultiSource(text.trim());
     } else {
        _fetchAI('Explain', 'Explain this: "$text"', text);
     }
  }

  void _fetchMultiSource(String term) async {
     // Show loading panel
     if(mounted) showModalBottomSheet(context: context, builder: (c) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())));
     
     try {
       final dictFuture = http.get(Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$term'));
       final wikiFuture = http.get(Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$term'));
       
       final results = await Future.wait([dictFuture, wikiFuture]);
       if(mounted) Navigator.pop(context); // Close loading
       
       String dictResult = "No definition found.";
       if (results[0].statusCode == 200) {
          final data = json.decode(results[0].body);
           if (data is List && data.isNotEmpty) {
             dictResult = data[0]['meanings']?[0]?['definitions']?[0]?['definition'] ?? "";
          }
       }
       
       String wikiResult = "No wiki entry found.";
       if (results[1].statusCode == 200) {
          final data = json.decode(results[1].body);
          wikiResult = data['extract'] ?? "";
       }
       
       if (mounted) _showMultiResultPanel(term, dictResult, wikiResult);

     } catch (e) {
        if(mounted) Navigator.pop(context);
        if(mounted) _fetchAI('Define', 'Define "$term"', term);
     }
  }

  void _showMultiResultPanel(String term, String dict, String wiki) {
     final textColor = _isNightMode ? Colors.white : Colors.black;
     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       backgroundColor: _isNightMode ? const Color(0xFF1E1E1E) : Colors.white,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
       builder: (context) => DraggableScrollableSheet(
         initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.9,
         expand: false,
         builder: (context, scrollController) => Container(
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: scrollController,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(term, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 16),
                _buildSection('Dictionary', dict, textColor),
                const SizedBox(height: 16),
                _buildSection('Wikipedia', wiki, textColor),
                const SizedBox(height: 24),
                Row(
                  children: [
                     Expanded(child: OutlinedButton(onPressed: () {Navigator.pop(context); _fetchAI('Deep Dive', 'Explain "$term" deep dive', term);}, child: const Text('Ask AI'))),
                     const SizedBox(width: 12),
                     Expanded(child: FilledButton(onPressed: () {Navigator.pop(context); _saveToNotes(term, "Dict: $dict\nWiki: $wiki");}, child: const Text('Save Note'))),
                  ],
                )
              ],
            ),
         ),
       ),
     );
  }

  Widget _buildSection(String title, String content, Color textColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _panelColor)),
       const SizedBox(height: 4),
       Text(content, style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 16)),
    ]);
  }

  void _showManualInput() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isNightMode ? Colors.grey[900] : Colors.white,
        title: Text('Ask AI', style: TextStyle(color: _isNightMode ? Colors.white : Colors.black)),
        content: TextField(controller: c, autofocus: true, style: TextStyle(color: _isNightMode ? Colors.white : Colors.black), decoration: const InputDecoration(hintText: 'What are you looking for?')),
        actions: [TextButton(onPressed: () {Navigator.pop(context); if(c.text.isNotEmpty) _processText(c.text);}, child: const Text('Go'))],
      ),
    );
  }
  
  void _fetchAI(String mode, String prompt, String originalText) async {
     if(mounted) showModalBottomSheet(context: context, builder: (c) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())));
     try {
       final response = await ref.read(aiServiceProvider).generateSummary(prompt);
       if(mounted) Navigator.pop(context);
       if (mounted) _showResultPanel(mode, originalText, response);
     } catch (e) {
       if(mounted) Navigator.pop(context);
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
     }
  }

  void _showResultPanel(String title, String subtitle, String content, {bool isError = false}) {
     if(!isError) {
       ref.read(storageServiceProvider).saveVisionHistory(subtitle, content);
     }
  
     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       backgroundColor: _isNightMode ? const Color(0xFF1E1E1E) : Colors.white,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
       builder: (context) => DraggableScrollableSheet(
         initialChildSize: 0.6,
         minChildSize: 0.4,
         maxChildSize: 0.9,
         expand: false,
         builder: (context, controller) => Padding(
           padding: const EdgeInsets.all(24),
           child: ListView(
             controller: controller,
             children: [
               Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
               const SizedBox(height: 20),
               Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 Text(title, style: TextStyle(color: _panelColor, fontWeight: FontWeight.bold, fontSize: 14)),
                 IconButton(icon: const Icon(LucideIcons.history, size: 20), onPressed: _showVisionHistory),
               ]),
               const SizedBox(height: 8),
               Text(subtitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isNightMode ? Colors.white : Colors.black)),
               const SizedBox(height: 16),
               Text(content, style: TextStyle(fontSize: 16, height: 1.6, color: _isNightMode ? Colors.grey[300] : Colors.grey[800])),
               const SizedBox(height: 24),
               Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   if (title != 'Analysis') 
                   TextButton.icon(
                     icon: const Icon(LucideIcons.refreshCcw, size: 16), 
                     label: const Text('Simplify'), 
                     onPressed: () { Navigator.pop(context); _fetchAI('Simply Put', 'Explain this to a 5 year old: "$content"', content); }
                   ),
                   const SizedBox(width: 16),
                   FilledButton(onPressed: () { Navigator.pop(context); _saveToNotes(subtitle, content); }, child: const Text('Save Note')),
                 ],
               )
             ],
           ),
         ),
       ),
     );
  }

  void _showChatPanel() {
    final textController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _isNightMode ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setPanelState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Chat with ${widget.book.author}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _panelColor)),
                const Divider(),
                Expanded(
                  child: _chatHistory.isEmpty 
                    ? Center(child: Text('Ask ${widget.book.author} anything!', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _chatHistory.length,
                        itemBuilder: (c, i) {
                          final msg = _chatHistory[i];
                          final isUser = msg['role'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser ? _panelColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(msg['content']!, style: TextStyle(color: _isNightMode ? Colors.white : Colors.black)),
                            ),
                          );
                        },
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(
                      controller: textController,
                      style: TextStyle(color: _isNightMode ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        filled: true,
                        fillColor: _isNightMode ? Colors.black26 : Colors.white,
                      ),
                    )),
                    IconButton(
                      icon: Icon(LucideIcons.send, color: _panelColor),
                      onPressed: () async {
                        final text = textController.text.trim();
                        if (text.isEmpty) return;
                        
                        setPanelState(() => _chatHistory.add({'role': 'user', 'content': text}));
                        textController.clear();
                        
                        try {
                          final response = await ref.read(aiServiceProvider).chatWithAuthor(widget.book.title, widget.book.author, text, _chatHistory);
                          setPanelState(() => _chatHistory.add({'role': 'author', 'content': response}));
                        } catch(e) {
                          setPanelState(() => _chatHistory.add({'role': 'author', 'content': 'Error: $e'}));
                        }
                      },
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showVisionHistory() async {
    final history = await ref.read(storageServiceProvider).getVisionHistory();
    if(!mounted) return;
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text('Vision History'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty ? const Text('No history found.') : ListView.builder(
            shrinkWrap: true,
            itemCount: history.length,
            itemBuilder: (c, i) => ListTile(
              title: Text(history[i]['query'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(history[i]['timestamp']?.substring(0, 10) ?? ''),
              onTap: () { Navigator.pop(c); _showResultPanel('History', history[i]['query']!, history[i]['result']!, isError: true); }, 
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () async { await ref.read(storageServiceProvider).clearVisionHistory(); Navigator.pop(c); }, child: const Text('Clear', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))
        ]
      )
    );
  }


  
  void _saveToNotes(String h, String s) {
    // Basic note to show in dialog
    final note = Note()..highlight = h..subtitle = s..bookId = widget.book.uuid..color = '0xFFFFF9C4';
    
    if(!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StickyNoteEditorDialog(
        initialNote: note,
        initialTextColor: Colors.black, // Default for new note
        onSave: (t, sub, txt, c, textColor, b, i, fs, ff) async {
           // Save via Repo (Isar)
           final savedNote = await ref.read(bookRepositoryProvider).addNote(
              bookId: widget.book.uuid, highlight: txt, title: t, subtitle: sub,
              color: '0x${c.value.toRadixString(16).toUpperCase()}', isBold: b, isItalic: i, fontSize: fs, fontFamily: ff
           );
           
           // Save Text Color via Storage (Prefs)
           await ref.read(storageServiceProvider).saveNoteTextColor(
             savedNote.id, 
             '0x${textColor.value.toRadixString(16).toUpperCase()}'
           );
        },
      ), 
    );
  }

  Future<void> _toggleAiRead() async {
    if (_isSpeaking) {
      await _tts?.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI is reading the page...'), duration: Duration(seconds: 2)));
      
      RenderRepaintBoundary boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/page_read_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
      final text = await ref.read(aiServiceProvider).extractTextFromImage(file);
      
      if (text.isNotEmpty) {
        setState(() => _isSpeaking = true);
        await _tts?.speak(text);
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No text found on this page.')));
      }
    } catch (e) {
      if(mounted) _showErrorDialog('AI Reading Failed', e.toString());
    }
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.red),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(fontSize: 14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
