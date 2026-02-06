import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

class StorageService {
  Future<void> saveSummary(String bookUuid, String summary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('summary_$bookUuid', summary);
  }

  Future<String?> getSummary(String bookUuid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('summary_$bookUuid');
  }

  Future<void> saveNoteTextColor(int noteId, String colorCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('note_text_color_$noteId', colorCode);
  }

  Future<String> getNoteTextColor(int noteId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('note_text_color_$noteId') ?? '0xFF000000';
  }

  // Favorites
  Future<void> toggleFavorite(String bookUuid) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favs = prefs.getStringList('favorites') ?? [];
    if (favs.contains(bookUuid)) {
      favs.remove(bookUuid);
    } else {
      favs.add(bookUuid);
    }
    await prefs.setStringList('favorites', favs);
  }

  Future<bool> isFavorite(String bookUuid) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favorites') ?? [];
    return favs.contains(bookUuid);
  }

  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('favorites') ?? [];
  }

  // AI Panel Color
  Future<void> savePanelColor(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ai_panel_color', colorValue);
  }

  Future<int> getPanelColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('ai_panel_color') ?? 0xFF2196F3; // Default Blue
  }

  // Vision History
  Future<void> saveVisionHistory(String query, String result) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList('vision_history') ?? [];
    final entry = '{"query": "$query", "result": "$result", "timestamp": "${DateTime.now().toIso8601String()}"}';
    history.insert(0, entry); // Add to top
    if (history.length > 50) history.removeLast(); // Limit to 50
    await prefs.setStringList('vision_history', history);
  }

  Future<List<Map<String, String>>> getVisionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList('vision_history') ?? [];
    return history.map((e) {
      // Simple manual JSON parse to avoid import if possible, but map is cleaner
      // Assuming naive JSON structure
      final clean = e.substring(1, e.length - 1); // remove {}
      final parts = clean.split('", "'); // simple split
      final map = <String, String>{};
      for(final part in parts) {
         final kv = part.split('": "');
         if(kv.length == 2) {
             map[kv[0].replaceAll('"', '').trim()] = kv[1].replaceAll('"', '').trim();
         }
      }
      return map;
    }).toList();
  }

  Future<void> clearVisionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vision_history');
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('summary_') || key.startsWith('note_text_color_') || key == 'favorites' || key == 'vision_history') {
        await prefs.remove(key);
      }
    }
  }
}
