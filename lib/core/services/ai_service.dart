import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/data/settings_repository.dart';

final aiServiceProvider = Provider<AIService>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return AIService(settingsRepo);
});

class AIService {
  final SettingsRepository _settings;
  
  // Available free models in priority order
  static const List<String> _freeModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite', 
    'gemini-3-flash',
    'gemini-2.5-flash-tts',
  ];
  
  int _currentModelIndex = 0;
  DateTime? _lastRateLimitTime;

  AIService(this._settings);

  Future<String> summarizeBook(String title, String author, {String language = 'English'}) async {
    return _executeWithFallback(() => generateSummary('Create a short, concise, high-quality summary for "$title" by $author in $language. Use bullet points for key takeaways. No fluff. Return response in $language.'));
  }

  Future<String> chatWithAuthor(String title, String author, String message, List<Map<String, String>> history) async {
    return _executeWithFallback(() async {
      final apiKey = _settings.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) throw Exception('API Key missing');

      final modelName = _getCurrentModel();
      final model = GenerativeModel(model: modelName, apiKey: apiKey);
      
      final prompt = '''
      Act as the author $author of the book "$title". 
      Answer the reader's question: "$message".
      Keep the answer concise, well-structured, and engaging. 
      Do NOT use Markdown bolding (no **). 
      Stay in character.
      ''';
      
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? "I'm lost for words.";
    });
  }

  Future<String> generateSummary(String promptText) async {
    return _executeWithFallback(() async {
      final apiKey = _settings.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Gemini API Key not set. Please add it in Settings.');
      }

      final modelName = _getCurrentModel();
      final model = GenerativeModel(model: modelName, apiKey: apiKey);
      final content = [Content.text(promptText)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        return response.text!;
      } else {
        throw Exception('No response generated.');
      }
    });
  }

  Future<String> extractTextFromImage(File imageFile) async {
    return _executeWithFallback(() async {
      final apiKey = _settings.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Gemini API Key not set.');
      }

      final modelName = _getCurrentModel();
      final model = GenerativeModel(model: modelName, apiKey: apiKey);
      final bytes = await imageFile.readAsBytes();
      final content = [
        Content.multi([
          TextPart('Extract all text visible in this image. Return ONLY the text. If it is a diagram, describe its labels.'),
          DataPart('image/png', bytes),
        ])
      ];

      final response = await model.generateContent(content);
      return response.text ?? '';
    });
  }
  
  // Get current model based on settings or auto-mode
  String _getCurrentModel() {
    final selectedModel = _settings.getSelectedAiModel();
    if (selectedModel != null && selectedModel != 'auto') {
      return selectedModel;
    }
    // Auto mode: use current index
    return _freeModels[_currentModelIndex % _freeModels.length];
  }
  
  // Execute with automatic fallback on rate limit
  Future<T> _executeWithFallback<T>(Future<T> Function() operation) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts < _freeModels.length) {
      try {
        return await operation();
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        
        // Check if it's a rate limit error
        if (_isRateLimitError(e.toString())) {
          _lastRateLimitTime = DateTime.now();
          
          // Auto-rotate to next model if in auto mode
          if (_settings.getSelectedAiModel() == null || _settings.getSelectedAiModel() == 'auto') {
            _currentModelIndex++;
            attempts++;
            
            // If we've tried all models, throw with helpful message
            if (attempts >= _freeModels.length) {
              throw Exception(
                'All AI models have reached their rate limits.\n'
                'Please wait ${_getRetryWaitTime()} or upgrade your plan.\n\n'
                'You can manually select a different model in Settings.'
              );
            }
            
            // Try next model
            continue;
          } else {
            // Manual mode: throw error with retry time
            throw Exception(
              'Rate limit reached for ${_getCurrentModel()}.\n'
              'Please retry in ${_getRetryWaitTime()}.\n\n'
              'Tip: Enable "Auto" mode in Settings to automatically switch models.'
            );
          }
        } else {
          // Not a rate limit error, throw immediately
          throw lastError;
        }
      }
    }
    
    throw lastError ?? Exception('AI request failed');
  }
  
  bool _isRateLimitError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('quota') || 
           lowerError.contains('rate limit') || 
           lowerError.contains('exceeded') ||
           lowerError.contains('429');
  }
  
  String _getRetryWaitTime() {
    if (_lastRateLimitTime == null) return '1 minute';
    final elapsed = DateTime.now().difference(_lastRateLimitTime!);
    final remaining = Duration(minutes: 1) - elapsed;
    if (remaining.inSeconds <= 0) return 'now';
    return '${remaining.inSeconds} seconds';
  }
  
  // Get list of available models for UI
  static List<String> getAvailableModels() => _freeModels;
}
