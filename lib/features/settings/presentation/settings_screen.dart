import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../settings/data/settings_repository.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../data/repositories/book_repository.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/services/storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(settingsRepositoryProvider);
    _apiKeyController = TextEditingController(text: repo.getGeminiApiKey() ?? '');
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey(String value) async {
    await ref.read(settingsRepositoryProvider).setGeminiApiKey(value.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API Key Saved')));
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(mode: ThemeMode.system, label: 'System Default', icon: LucideIcons.smartphone),
            _ThemeOption(mode: ThemeMode.light, label: 'Light Mode', icon: LucideIcons.sun),
            _ThemeOption(mode: ThemeMode.dark, label: 'Dark Mode', icon: LucideIcons.moon),
          ],
        ),
      ),
    );
  }

  void _showClearLibraryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Library?'),
        content: const Text('This will delete ALL books and notes physically from your device. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
               Navigator.pop(context);
               final repo = ref.read(bookRepositoryProvider);
               final books = await repo.getAllBooks();
               for (final book in books) {
                 await repo.deleteBook(book.id);
               }
               await ref.read(storageServiceProvider).clearAllData(); // Also clear cache
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Library Cleared')));
            },
            child: const Text('Delete Everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text('This will remove generated summaries and text color preferences. Your books and written notes will remain safe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
             onPressed: () async {
                Navigator.pop(context);
                await ref.read(storageServiceProvider).clearAllData();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache Cleared')));
             },
             child: const Text('Clear Cache', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showColorPickerDialog() async {
    Color currentColor = Color(await ref.read(storageServiceProvider).getPanelColor());
    if(!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vision Panel Color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: currentColor,
            availableColors: const [
              Colors.blue, Colors.pink, Colors.purple, Colors.teal, 
              Colors.orange, Colors.green, Colors.red, Colors.indigo,
              Colors.cyan, Colors.amber, Colors.lime, Colors.brown
            ],
            onColorChanged: (color) {
              ref.read(storageServiceProvider).savePanelColor(color.value);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Color Saved')));
            },
          ),
        ),
      ),
    );
  }

  void _showModelDialog() {
    final current = ref.read(settingsRepositoryProvider).getSelectedAiModel() ?? 'auto';
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('AI Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(title: const Text('Auto'), subtitle: const Text('Switches on rate limit'), value: 'auto', groupValue: current, dense: true, onChanged: (v) { ref.read(settingsRepositoryProvider).setSelectedAiModel(v!); Navigator.pop(c); setState(() {}); }),
            RadioListTile(title: const Text('gemini-2.5-flash'), value: 'gemini-2.5-flash', groupValue: current, dense: true, onChanged: (v) { ref.read(settingsRepositoryProvider).setSelectedAiModel(v!); Navigator.pop(c); setState(() {}); }),
            RadioListTile(title: const Text('gemini-2.5-flash-lite'), value: 'gemini-2.5-flash-lite', groupValue: current, dense: true, onChanged: (v) { ref.read(settingsRepositoryProvider).setSelectedAiModel(v!); Navigator.pop(c); setState(() {}); }),
            RadioListTile(title: const Text('gemini-3-flash'), value: 'gemini-3-flash', groupValue: current, dense: true, onChanged: (v) { ref.read(settingsRepositoryProvider).setSelectedAiModel(v!); Navigator.pop(c); setState(() {}); }),
          ],
        ),
      ),
    );
  }

  void _showVoiceDialog() {
    final current = ref.read(settingsRepositoryProvider).getTtsVoice();
    final voices = {'en-us-x-tpf-local': 'US Female', 'en-us-x-tpm-local': 'US Male', 'en-us-x-iob-local': 'US Female 2', 'en-us-x-iom-local': 'US Male 2', 'en-gb-x-gba-local': 'British Female', 'en-gb-x-gbb-local': 'British Male', 'en-in-x-ahp-local': 'Indian Female', 'en-in-x-ene-local': 'Indian Male'};
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Voice'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: voices.entries.map((e) => RadioListTile(title: Text(e.value), value: e.key, groupValue: current, dense: true, onChanged: (v) { ref.read(settingsRepositoryProvider).setTtsVoice(v!); Navigator.pop(c); setState(() {}); })).toList(),
          ),
        ),
      ),
    );
  }

  String _getModelLabel() {
    final m = ref.read(settingsRepositoryProvider).getSelectedAiModel();
    return (m == null || m == 'auto') ? 'Auto' : m.split('-').last;
  }

  String _getVoiceLabel() {
    final v = ref.read(settingsRepositoryProvider).getTtsVoice();
    if (v.contains('tpf')) return 'US Female';
    if (v.contains('tpm')) return 'US Male';
    if (v.contains('iob')) return 'US Female 2';
    if (v.contains('iom')) return 'US Male 2';
    if (v.contains('gba')) return 'British Female';
    if (v.contains('gbb')) return 'British Male';
    if (v.contains('ahp')) return 'Indian Female';
    if (v.contains('ene')) return 'Indian Male';
    return 'Default';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTheme = ref.watch(themeModeProvider);

    String themeLabel;
    switch (currentTheme) {
      case ThemeMode.light: themeLabel = 'Light Mode'; break;
      case ThemeMode.dark: themeLabel = 'Dark Mode'; break;
      case ThemeMode.system: themeLabel = 'System Default'; break;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: 'Appearance',
            children: [
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(LucideIcons.palette, color: theme.colorScheme.primary)),
                title: const Text('Theme'),
                subtitle: Text(themeLabel),
                trailing: const Icon(LucideIcons.chevronRight, size: 20),
                onTap: _showThemeDialog,
              ),
              const Divider(indent: 56),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.pink.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.scanLine, color: Colors.pink)),
                title: const Text('AI Vision Color'),
                subtitle: const Text('Customize panel overlay'),
                trailing: const Icon(LucideIcons.chevronRight, size: 20),
                onTap: _showColorPickerDialog,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Intelligence',
            children: [
               ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.brainCircuit, color: Colors.purple)),
                title: const Text('Gemini API Key'),
                subtitle: const Text('Required for Summaries & Simplify'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    hintText: 'Paste API Key here',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    suffixIcon: IconButton(icon: const Icon(LucideIcons.save, size: 20), onPressed: () => _saveApiKey(_apiKeyController.text)),
                  ),
                  obscureText: true,
                  onSubmitted: _saveApiKey,
                ),
              ),
              const Divider(indent: 56),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.cpu, color: Colors.blue)),
                title: const Text('AI Model'),
                subtitle: Text(_getModelLabel()),
                trailing: const Icon(LucideIcons.chevronRight, size: 20),
                onTap: _showModelDialog,
              ),
              const Divider(indent: 56),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.volume2, color: Colors.green)),
                title: const Text('TTS Voice'),
                subtitle: Text(_getVoiceLabel()),
                trailing: const Icon(LucideIcons.chevronRight, size: 20),
                onTap: _showVoiceDialog,
              ),
            ],
          ),

          const SizedBox(height: 24),
          _SettingsSection(
             title: 'Storage & Data',
             children: [
               ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.database, color: Colors.orange)),
                title: const Text('Clear AI Cache'),
                subtitle: const Text('Reset summaries and colors'),
                onTap: () => _showClearCacheDialog(context, ref),
              ),
              const Divider(indent: 56),
               ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.trash2, color: Colors.red)),
                title: const Text('Clear Library', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Delete all books'),
                onTap: () => _showClearLibraryDialog(context, ref),
              ),
             ],
          ),

          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Text('Vellum', style: GoogleFonts.libreBaskerville(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('v1.2.0', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Crafted with '),
                    const Icon(LucideIcons.heart, size: 14, color: Colors.red),
                    const Text(' by '),
                    Text('Kavan & Amrita', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 12, bottom: 8), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))),
        Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withOpacity(0.2))), clipBehavior: Clip.antiAlias, child: Column(children: children)),
      ],
    );
  }
}

class _ThemeOption extends ConsumerWidget {
  final ThemeMode mode;
  final String label;
  final IconData icon;
  const _ThemeOption({required this.mode, required this.label, required this.icon});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(themeModeProvider) == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? const Icon(LucideIcons.check, color: Colors.green) : null,
      onTap: () { ref.read(themeModeProvider.notifier).setTheme(mode); Navigator.pop(context); },
    );
  }
}
