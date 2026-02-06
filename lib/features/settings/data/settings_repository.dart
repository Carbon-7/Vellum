import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError(); // Override in main
});

class SettingsRepository {
  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  static const _keyGeminiApiKey = 'gemini_api_key';
  static const _keyThemeMode = 'theme_mode'; // 'light', 'dark', 'sepia'
  static const _keySelectedAiModel = 'selected_ai_model'; // 'auto' or specific model
  static const _keyTtsVoice = 'tts_voice'; // Voice name for TTS

  Future<void> setGeminiApiKey(String key) async {
    await _prefs.setString(_keyGeminiApiKey, key);
  }

  String? getGeminiApiKey() {
    return _prefs.getString(_keyGeminiApiKey);
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
  }

  String getThemeMode() {
    return _prefs.getString(_keyThemeMode) ?? 'light';
  }
  
  // AI Model Selection
  Future<void> setSelectedAiModel(String model) async {
    await _prefs.setString(_keySelectedAiModel, model);
  }
  
  String? getSelectedAiModel() {
    return _prefs.getString(_keySelectedAiModel) ?? 'auto';
  }
  
  // TTS Voice Selection
  Future<void> setTtsVoice(String voice) async {
    await _prefs.setString(_keyTtsVoice, voice);
  }
  
  String getTtsVoice() {
    return _prefs.getString(_keyTtsVoice) ?? 'en-us-x-tpf-local'; // Google's enhanced female voice
  }
}
