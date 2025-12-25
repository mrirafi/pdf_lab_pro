import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pdf_lab_pro/models/recent_file.dart';
import 'package:pdf_lab_pro/services/file_service.dart';

class FileProvider extends Notifier<List<RecentFile>> {

  late FileService _fileService;

  @override
  List<RecentFile> build() {
    _fileService = FileService();
    // Initial load can be done here or separately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadRecentFiles();
    });
    return [];
  }

  Future<void> loadRecentFiles() async {
    try {
      final files = await _fileService.listPDFFiles();
      final recentFiles = files.take(3).map((file) {
        return RecentFile(
          path: file['path'] ?? '',
          name: file['name'] ?? 'Unknown',
          size: file['size'] ?? '0 B',
          date: file['date'] ?? 'Unknown',
          icon: Icons.picture_as_pdf,
        );
      }).toList();
      state = recentFiles;
    } catch (_) {
      state = [];
    }
  }

  /// Copy file into app directory and return the stored path
  Future<String> addFile(String filePath) async {
    final copied = await _fileService.copyToAppDirectory(filePath);
    await loadRecentFiles();
    return copied.path; // return path in app directory
  }


  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        await loadRecentFiles();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearAllFiles() async {
    try {
      await _fileService.clearAppDirectory();
      state = [];
    } catch (e) {
      rethrow;
    }
  }
}

final fileProvider = NotifierProvider<FileProvider, List<RecentFile>>(
      () => FileProvider(),
);
