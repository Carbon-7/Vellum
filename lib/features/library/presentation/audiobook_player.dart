import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import '../../data/models/book.dart';
import '../../settings/data/settings_repository.dart';

class AudiobookPlayer extends ConsumerStatefulWidget {
  final Book book;
  
  const AudiobookPlayer({super.key, required this.book});
  
  @override
  ConsumerState<AudiobookPlayer> createState() => _AudiobookPlayerState();
}

class _AudiobookPlayerState extends ConsumerState<AudiobookPlayer> {
  FlutterTts? _tts;
  bool _isPlaying = false;
  bool _isPaused = false;
  double _speechRate = 0.7;
  int _currentPageIndex = 0;
  List<String> _pageTexts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Duration _estimatedDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTts();
      _extractPdfText();
    });
  }
  
  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts?.setSharedInstance(true);
    
    final selectedVoice = ref.read(settingsRepositoryProvider).getTtsVoice();
    await _tts?.setVoice({"name": selectedVoice, "locale": "en-US"});
    await _tts?.setSpeechRate(_speechRate);
    await _tts?.setVolume(1.0);
    await _tts?.setPitch(1.0);
    
    _tts?.setCompletionHandler(() {
      if (mounted && _isPlaying && !_isPaused) {
        _currentPageIndex++;
        if (_currentPageIndex >= _pageTexts.length) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _currentPageIndex = 0;
              _currentPosition = Duration.zero;
            });
          }
        } else {
          _updatePosition();
          _speakCurrentPage();
        }
      }
    });
  }
  
  Future<void> _extractPdfText() async {
    try {
      final file = File(widget.book.filePath);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _errorMessage = 'PDF file not found';
            _isLoading = false;
          });
        }
        return;
      }
      
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      for (int i = 0; i < document.pages.count; i++) {
        final String text = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
        final cleanText = text.trim();
        
        if (cleanText.isNotEmpty && cleanText.length > 50) {
          _pageTexts.add(cleanText);
        }
      }
      
      document.dispose();
      
      int totalWords = _pageTexts.fold(0, (sum, text) => sum + text.split(' ').length);
      _estimatedDuration = Duration(minutes: (totalWords / 150 / _speechRate).ceil());
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_pageTexts.isEmpty) {
            _errorMessage = 'No readable text found in PDF';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error extracting PDF: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  void _updatePosition() {
    if (_pageTexts.isEmpty) return;
    final wordsPerPage = _pageTexts[_currentPageIndex].split(' ').length;
    final minutesForPage = wordsPerPage / 150 / _speechRate;
    _currentPosition += Duration(seconds: (minutesForPage * 60).ceil());
    if (mounted) setState(() {});
  }
  
  @override
  void dispose() {
    _tts?.stop();
    super.dispose();
  }
  
  Future<void> _togglePlayPause() async {
    if (_pageTexts.isEmpty) return;
    
    if (_isPlaying && !_isPaused) {
      await _tts?.stop();
      setState(() => _isPaused = true);
    } else {
      setState(() {
        _isPlaying = true;
        _isPaused = false;
      });
      await _speakCurrentPage();
    }
  }
  
  Future<void> _speakCurrentPage() async {
    if (_currentPageIndex < _pageTexts.length) {
      await _tts?.speak(_pageTexts[_currentPageIndex]);
    }
  }
  
  Future<void> _stop() async {
    await _tts?.stop();
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _currentPageIndex = 0;
      _currentPosition = Duration.zero;
    });
  }
  
  Future<void> _changeSpeechRate(double rate) async {
    setState(() => _speechRate = rate);
    await _tts?.setSpeechRate(rate);
    int totalWords = _pageTexts.fold(0, (sum, text) => sum + text.split(' ').length);
    _estimatedDuration = Duration(minutes: (totalWords / 150 / rate).ceil());
  }
  
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('Loading Audiobook'),
          backgroundColor: theme.colorScheme.surface,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Extracting PDF text...', style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text('This may take a moment', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: theme.colorScheme.surface,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertCircle, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Audiobook Player'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Book Cover
                Container(
                  width: 220,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Color(int.parse((widget.book.coverColor ?? '#795548').replaceFirst('#', '0xFF'))),
                      child: const Center(
                        child: Icon(LucideIcons.book, size: 80, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Book Info
                Text(
                  widget.book.title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.book.author,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Timeline
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: _estimatedDuration.inSeconds > 0 
                        ? _currentPosition.inSeconds / _estimatedDuration.inSeconds 
                        : 0,
                    onChanged: (v) {},
                    activeColor: theme.colorScheme.primary,
                    inactiveColor: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_currentPosition), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(_formatDuration(_estimatedDuration), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Playback Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.skipBack),
                      iconSize: 36,
                      onPressed: () {
                        if (_currentPageIndex > 0) {
                          setState(() => _currentPageIndex--);
                        }
                      },
                    ),
                    const SizedBox(width: 24),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isPlaying && !_isPaused ? LucideIcons.pause : LucideIcons.play,
                          color: Colors.white,
                        ),
                        iconSize: 36,
                        onPressed: _togglePlayPause,
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(LucideIcons.skipForward),
                      iconSize: 36,
                      onPressed: () {
                        if (_currentPageIndex < _pageTexts.length - 1) {
                          setState(() => _currentPageIndex++);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Speed Control
                Row(
                  children: [
                    const Icon(LucideIcons.gauge, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: _speechRate,
                          min: 0.5,
                          max: 2.0,
                          divisions: 6,
                          label: '${_speechRate.toStringAsFixed(1)}x',
                          onChanged: _changeSpeechRate,
                        ),
                      ),
                    ),
                    Text('${_speechRate.toStringAsFixed(1)}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 40),
                // Stop Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(LucideIcons.stopCircle),
                    label: const Text('Stop Audiobook'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
