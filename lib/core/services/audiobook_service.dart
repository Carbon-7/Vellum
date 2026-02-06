import 'dart:async';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/data/models/book.dart';
import 'ai_service.dart';

final audiobookServiceProvider = Provider<AudiobookService>((ref) {
  return AudiobookService(ref);
});

class AudiobookService {
  final Ref _ref;
  FlutterTts? _tts;
  bool _isPlaying = false;
  bool _isPaused = false;
  int _currentPage = 0;
  Book? _currentBook;
  List<String> _pageTexts = [];
  double _speechRate = 0.5;
  
  AudiobookService(this._ref) {
    _initTts();
  }
  
  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts?.setSharedInstance(true);
    await _tts?.awaitSpeakCompletion(true);
    
    // Get voice from settings
    final selectedVoice = _ref.read(settingsRepositoryProvider).getTtsVoice();
    await _tts?.setVoice({"name": selectedVoice, "locale": "en-US"});
    
    await _tts?.setSpeechRate(_speechRate);
    await _tts?.setVolume(1.0);
    await _tts?.setPitch(1.0);
    
    _tts?.setCompletionHandler(() {
      _onPageComplete();
    });
    
    _tts?.setErrorHandler((msg) {
      print('TTS Error: $msg');
      _isPlaying = false;
    });
  }
  
  Future<void> startAudiobook(Book book, int startPage, AIService aiService) async {
    _currentBook = book;
    _currentPage = startPage;
    _pageTexts.clear();
    
    // Extract text from current page using AI
    // For now, we'll use a placeholder - in real implementation,
    // you'd capture the page and use aiService.extractTextFromImage
    
    _isPlaying = true;
    _isPaused = false;
    
    // Speak current page
    await _speakCurrentPage();
  }
  
  Future<void> _speakCurrentPage() async {
    if (_currentPage < _pageTexts.length && _pageTexts[_currentPage].isNotEmpty) {
      await _tts?.speak(_pageTexts[_currentPage]);
    }
  }
  
  void _onPageComplete() {
    if (!_isPlaying || _isPaused) return;
    
    // Move to next page
    _currentPage++;
    
    if (_currentPage < _pageTexts.length) {
      _speakCurrentPage();
    } else {
      // End of book
      _isPlaying = false;
    }
  }
  
  Future<void> pause() async {
    if (_isPlaying && !_isPaused) {
      await _tts?.pause();
      _isPaused = true;
    }
  }
  
  Future<void> resume() async {
    if (_isPlaying && _isPaused) {
      // Note: flutter_tts doesn't support resume, so we restart from current position
      _isPaused = false;
      await _speakCurrentPage();
    }
  }
  
  Future<void> stop() async {
    await _tts?.stop();
    _isPlaying = false;
    _isPaused = false;
  }
  
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 2.0);
    await _tts?.setSpeechRate(_speechRate);
  }
  
  Future<void> nextPage() async {
    if (_currentPage < _pageTexts.length - 1) {
      await _tts?.stop();
      _currentPage++;
      await _speakCurrentPage();
    }
  }
  
  Future<void> previousPage() async {
    if (_currentPage > 0) {
      await _tts?.stop();
      _currentPage--;
      await _speakCurrentPage();
    }
  }
  
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  int get currentPage => _currentPage;
  double get speechRate => _speechRate;
}
