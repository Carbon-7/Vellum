import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/book_repository.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool _isUploading = false;

  /// Request storage permissions
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Check Android version
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      
      if (androidInfo.version.sdkInt >= 30) {
        // Android 11+ requires MANAGE_EXTERNAL_STORAGE
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      } else {
        // Android 10 and below
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true; // iOS doesn't need explicit storage permission for file picker
  }

  /// Select and import multiple files
  Future<void> _selectFiles() async {
    // Request permissions
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to import books'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        await _importFiles(result.files);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting files: $e')),
        );
      }
    }
  }

  /// Select and import all books from a folder
  Future<void> _selectFolder() async {
    // Request permissions
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to import books'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final result = await FilePicker.platform.getDirectoryPath();

      if (result != null) {
        final directory = Directory(result);
        final files = directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) {
          final path = file.path.toLowerCase();
          return path.endsWith('.pdf') || path.endsWith('.epub');
        }).toList();

        if (files.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No PDF or EPUB files found in this folder'),
              ),
            );
          }
          return;
        }

        // Convert to PlatformFile format
        final platformFiles = files.map((file) {
          return PlatformFile(
            path: file.path,
            name: file.path.split(Platform.pathSeparator).last,
            size: file.lengthSync(),
          );
        }).toList();

        await _importFiles(platformFiles);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting folder: $e')),
        );
      }
    }
  }

  /// Import files to the database
  Future<void> _importFiles(List<PlatformFile> files) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final bookRepository = ref.read(bookRepositoryProvider);
      final existingBooks = await bookRepository.getAllBooks();
      
      // Create a set of identifying signatures for existing books to prevent duplicates.
      // We use file size as a primary proxy for "exact same file" since we don't have hashes.
      final existingSignatures = <int>{};
      for (final book in existingBooks) {
        try {
           final f = File(book.filePath);
           if (f.existsSync()) {
             existingSignatures.add(f.lengthSync());
           }
        } catch (_) {}
      }

      int successCount = 0;
      int failCount = 0;
      int skippedCount = 0;

      for (final platformFile in files) {
        if (platformFile.path != null) {
          try {
            final file = File(platformFile.path!);
            if (!file.existsSync()) continue;
            
            final length = file.lengthSync();
            
            // Duplicate Check
            if (existingSignatures.contains(length)) {
              skippedCount++;
              continue; // Skip exact duplicate file
            }
            
            await bookRepository.addBook(file);
            existingSignatures.add(length); // Add to set to prevent duplicates within the same batch
            successCount++;
          } catch (e) {
            failCount++;
            debugPrint('Failed to import ${platformFile.name}: $e');
          }
        }
      }

      if (mounted) {
        // Show success message
        String message = 'Library Updated: $successCount added';
        if (skippedCount > 0) message += ', $skippedCount duplicates skipped';
        if (failCount > 0) message += ', $failCount failed';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: (failCount > 0) ? Colors.orange : (successCount > 0 ? Colors.green : Colors.grey),
          ),
        );

        // Navigate back to home
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing books: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Import Books', style: GoogleFonts.libreBaskerville(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: Container(
        // Subtle texture or solid background from theme
        color: theme.scaffoldBackgroundColor,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                     padding: const EdgeInsets.all(32),
                     decoration: BoxDecoration(
                       color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                       shape: BoxShape.circle,
                     ),
                     child: Icon(LucideIcons.library, size: 64, color: theme.colorScheme.primary)
                   ),
                   const SizedBox(height: 32),
                   Text('Build Your Library', style: theme.textTheme.headlineMedium),
                   const SizedBox(height: 12),
                   Text('Import EPUB or PDF files to start reading', style: theme.textTheme.bodyMedium),
                   const SizedBox(height: 64),
                   
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                        _UploadCard(
                          icon: LucideIcons.fileUp, 
                          label: 'Select Files', 
                          onTap: _isUploading ? null : _selectFiles,
                          color: theme.colorScheme.secondary
                        ),
                        const SizedBox(width: 24),
                        _UploadCard(
                          icon: LucideIcons.folderPlus, 
                          label: 'Select Folder', 
                          onTap: _isUploading ? null : _selectFolder, 
                          color: theme.colorScheme.primary
                        ),
                     ],
                   ),
                   
                   const SizedBox(height: 48),
                   Text('Tap "Select Files" for Google Drive', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            
            if (_isUploading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text('Importing books...', style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _UploadCard({required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 150,
          height: 150,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
             borderRadius: BorderRadius.circular(20),
             border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 16),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
