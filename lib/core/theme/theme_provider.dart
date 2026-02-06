import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/data/settings_repository.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return ThemeModeNotifier(settingsRepo);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SettingsRepository _settings;

  ThemeModeNotifier(this._settings) : super(ThemeMode.system) {
    _loadTheme();
  }

  void _loadTheme() {
    final savedMode = _settings.getThemeMode(); // Returns string 'light', 'dark', 'system'
    switch (savedMode) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    String modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      default:
        modeStr = 'system';
    }
    await _settings.setThemeMode(modeStr);
  }
}
