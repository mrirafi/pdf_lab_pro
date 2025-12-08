import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pdf_lab_pro/models/recent_file.dart';
import 'package:pdf_lab_pro/services/file_service.dart';

class FileProvider extends StateNotifier<List<RecentFile>> {
  FileProvider() : super([]);

  final FileService _fileService = FileService();

  Future<void> loadFiles() async {
    try {
      final result = await _fileService.listPDFFiles();
      state = result.map((file) {
        return RecentFile(
          path: file['path'],
          name: file['name'],
          size: file['size'],
          date: file['date'],
          icon: file['icon'],
        );
      }).toList();
    } catch (_) {
      state = [];
    }
  }

  Future<void> addFile(String path) async {
    try {
      await _fileService.copyToAppDirectory(path);
      await loadFiles();
    } catch (_) {}
  }

  Future<void> deleteFile(String path) async {
    try {
      await _fileService.deleteFile(path);
      await loadFiles();
    } catch (_) {}
  }
}

final fileProvider = StateNotifierProvider<FileProvider, List<RecentFile>>(
      (ref) => FileProvider()..loadFiles(),
);
