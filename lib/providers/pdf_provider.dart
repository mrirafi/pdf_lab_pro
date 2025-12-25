import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_lab_pro/services/activity_tracker.dart';
import 'package:pdf_lab_pro/services/pdf_merge_service.dart';
import 'package:pdf_lab_pro/services/file_service.dart';

import 'package:path/path.dart' as p;

class PdfState {
  final bool isLoading;
  final String? error;
  final String? success;
  final List<String> selectedFiles;
  final Map<String, dynamic>? fileInfo;
  final String? mergedFilePath;
  final List<Map<String, dynamic>> selectedFilesInfo;

  const PdfState({
    this.isLoading = false,
    this.error,
    this.success,
    this.selectedFiles = const [],
    this.fileInfo,
    this.mergedFilePath,
    this.selectedFilesInfo = const [],
  });

  PdfState copyWith({
    bool? isLoading,
    String? error,
    String? success,
    List<String>? selectedFiles,
    Map<String, dynamic>? fileInfo,
    String? mergedFilePath,
    List<Map<String, dynamic>>? selectedFilesInfo,
  }) {
    return PdfState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      fileInfo: fileInfo ?? this.fileInfo,
      mergedFilePath: mergedFilePath ?? this.mergedFilePath,
      selectedFilesInfo: selectedFilesInfo ?? this.selectedFilesInfo,
    );
  }
}

// Modern Notifier class (extends Notifier<PdfState> instead of StateNotifier<PdfState>)
class PdfProvider extends Notifier<PdfState> {
  late FileService _fileService;
  late PdfMergeService _pdfMergeService;

  // The build method initializes the state
  @override
  PdfState build() {
    // Initialize services
    _fileService = FileService();
    _pdfMergeService = PdfMergeService();

    // Return initial state
    return const PdfState();
  }

  // Select a file and load its info
  Future<void> selectFile(String filePath) async {
    if (!state.selectedFiles.contains(filePath)) {
      state = state.copyWith(
        selectedFiles: [...state.selectedFiles, filePath],
        error: null,
        success: null,
      );

      // Load file info
      await _loadFileInfo(filePath);
    }
  }

  // Deselect a file
  void deselectFile(String filePath) {
    final newFiles = state.selectedFiles.where((f) => f != filePath).toList();
    final newFilesInfo = state.selectedFilesInfo
        .where((info) => info['path'] != filePath)
        .toList();

    state = state.copyWith(
      selectedFiles: newFiles,
      selectedFilesInfo: newFilesInfo,
      error: null,
      success: null,
    );
  }


  // Load file info
  Future<void> _loadFileInfo(String filePath) async {
    try {
      final info = await _pdfMergeService.getFileInfo(filePath);
      final newFilesInfo = [...state.selectedFilesInfo];

      // Check if info already exists
      final existingIndex = newFilesInfo.indexWhere((i) => i['path'] == filePath);
      if (existingIndex >= 0) {
        newFilesInfo[existingIndex] = info;
      } else {
        newFilesInfo.add(info);
      }

      state = state.copyWith(selectedFilesInfo: newFilesInfo);
    } catch (e) {
      // Error is handled gracefully
    }
  }

  // Merge selected files
  Future<String?> mergeSelectedFiles() async {
    if (state.selectedFiles.length < 2) {
      state = state.copyWith(
        error: 'Select at least 2 files to merge',
        success: null,
      );
      return null;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      success: null,
      mergedFilePath: null,
    );

    try {
      // Determine file types
      final hasPdf = state.selectedFiles.any((path) =>
          path.toLowerCase().endsWith('.pdf'));
      final hasImages = state.selectedFiles.any((path) {
        final ext = path.toLowerCase();
        return ext.endsWith('.jpg') ||
            ext.endsWith('.jpeg') ||
            ext.endsWith('.png') ||
            ext.endsWith('.bmp') ||
            ext.endsWith('.gif') ||
            ext.endsWith('.webp');
      });

      String mergedPath;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputName = 'merged_$timestamp.pdf';

      if (hasPdf && hasImages) {
        // Merge PDFs with images
        mergedPath = await _pdfMergeService.mergePdfsWithImages(
          filePaths: state.selectedFiles,
          outputFileName: outputName,
        );
      } else if (hasPdf) {
        // Merge only PDFs
        mergedPath = await _pdfMergeService.mergePdfs(
          pdfPaths: state.selectedFiles,
          outputFileName: outputName,
        );
      } else {
        // Merge only images (convert to PDF)
        mergedPath = await _pdfMergeService.mergePdfsWithImages(
          filePaths: state.selectedFiles,
          outputFileName: outputName,
        );
      }

      // Save to app directory
      final savedFile = await _pdfMergeService.saveToAppDirectory(
        mergedPath,
        customName: 'merged_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      state = state.copyWith(
        isLoading: false,
        success: 'Successfully merged ${state.selectedFiles.length} files',
        mergedFilePath: savedFile.path,
      );

      await ActivityTracker.logActivity(
        type: ActivityType.merge,
        title: 'Merged PDF',
        description: 'Merged ${state.selectedFiles.length} files',
        filePath: savedFile.path,
        extraData: {
          'fileCount': state.selectedFiles.length,
          'originalFiles': state.selectedFiles.map((f) => p.basename(f)).toList(),
        },
      );

      return savedFile.path;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '❌ Failed to merge files: $e',
        success: null,
        mergedFilePath: null,
      );
      return null;
    }
  }
// Add this method to PdfProvider class:
  void reorderFiles(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.selectedFiles.length ||
        newIndex < 0 || newIndex >= state.selectedFiles.length) {
      return;
    }

    final newFiles = List<String>.from(state.selectedFiles);
    final newFilesInfo = List<Map<String, dynamic>>.from(state.selectedFilesInfo);

    // Move file
    final file = newFiles.removeAt(oldIndex);
    final fileInfo = newFilesInfo.removeAt(oldIndex);

    newFiles.insert(newIndex, file);
    newFilesInfo.insert(newIndex, fileInfo);

    state = state.copyWith(
      selectedFiles: newFiles,
      selectedFilesInfo: newFilesInfo,
    );
  }
  // Save merged file to app directory
  Future<File?> saveMergedFile() async {
    if (state.mergedFilePath == null) return null;

    try {
      final file = File(state.mergedFilePath!);
      if (await file.exists()) {
        final savedFile = await _fileService.copyToAppDirectory(state.mergedFilePath!);
        return savedFile;
      }
    } catch (e) {
      // Error is handled gracefully
    }
    return null;
  }

  // Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Clear success message
  void clearSuccess() {
    state = state.copyWith(success: null);
  }

  // Reset everything (refreshes the provider)
  void reset() {
    state = const PdfState();
  }
}

final pdfProvider = NotifierProvider<PdfProvider, PdfState>(PdfProvider.new);
