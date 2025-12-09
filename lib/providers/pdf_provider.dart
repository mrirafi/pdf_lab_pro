import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pdf_combiner/pdf_combiner.dart';
import 'package:pdf_combiner/responses/merge_multiple_pdf_response.dart';
import 'package:pdf_combiner/responses/pdf_combiner_status.dart';
import 'package:pdf_lab_pro/services/file_service.dart';
import 'package:pdf_lab_pro/services/pdf_extractor.dart';

/// Immutable state for PDF-related operations
class PdfState {
  final bool isLoading;
  final String? error;
  final List<String> selectedFiles;
  final Map<String, dynamic>? pdfInfo;
  final String? extractedText;

  const PdfState({
    this.isLoading = false,
    this.error,
    this.selectedFiles = const [],
    this.pdfInfo,
    this.extractedText,
  });

  PdfState copyWith({
    bool? isLoading,
    String? error,
    List<String>? selectedFiles,
    Map<String, dynamic>? pdfInfo,
    String? extractedText,
  }) {
    return PdfState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      pdfInfo: pdfInfo ?? this.pdfInfo,
      extractedText: extractedText ?? this.extractedText,
    );
  }
}

/// PDF Provider – handles selection & operations (merge, split, etc.)
class PdfProvider extends StateNotifier<PdfState> {
  final FileService _fileService;

  PdfProvider({FileService? fileService})
      : _fileService = fileService ?? FileService(),
        super(const PdfState());

  // -----------------------------
  // Selection handling
  // -----------------------------
  void selectFile(String filePath) {
    if (!state.selectedFiles.contains(filePath)) {
      state = state.copyWith(
        selectedFiles: [...state.selectedFiles, filePath],
        error: null,
      );
    }
  }

  void deselectFile(String filePath) {
    state = state.copyWith(
      selectedFiles:
      state.selectedFiles.where((f) => f != filePath).toList(),
      error: null,
    );
  }

  void clearSelection() {
    state = state.copyWith(selectedFiles: [], error: null);
  }

  bool isSelected(String filePath) =>
      state.selectedFiles.contains(filePath);

  int get selectedCount => state.selectedFiles.length;

  List<String> get selectedFileNames {
    return state.selectedFiles
        .map((p) => File(p).uri.pathSegments.isNotEmpty
        ? File(p).uri.pathSegments.last
        : p.split('/').last)
        .toList();
  }

  // -----------------------------
  // Info / text extraction
  // -----------------------------
  Future<void> loadPdfInfo(String filePath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final info = await PdfExtractor.getMetadata(filePath);
      state = state.copyWith(
        pdfInfo: info,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load PDF info: $e',
        isLoading: false,
      );
    }
  }

  Future<void> extractPdfText(String filePath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final text = await PdfExtractor.extractText(filePath);
      state = state.copyWith(
        extractedText: text,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to extract text: $e',
        isLoading: false,
      );
    }
  }

  // -----------------------------
  // REAL MERGE IMPLEMENTATION
  // -----------------------------

  /// Core merge function: merges [state.selectedFiles] into a single PDF file
  /// saved inside the app's documents directory.
  ///
  /// Returns:
  ///   - String path of the merged PDF on success
  ///   - null on failure (error message stored in [state.error])
  Future<String?> mergeSelectedPdfsToFile() async {
    if (state.selectedFiles.length < 2) {
      state = state.copyWith(
        error: 'Select at least 2 PDF files to merge',
      );
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Where we will save the merged file
      final appDir = await _fileService.getAppDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${appDir.path}/Merged_$timestamp.pdf';

      final response = await PdfCombiner.mergeMultiplePDFs(
        inputPaths: state.selectedFiles,
        outputPath: outputPath,
      );

      if (response.status == PdfCombinerStatus.success) {
        // Clear selection after success
        state = state.copyWith(
          isLoading: false,
          selectedFiles: [],
          error: null,
        );
        // response.response = outputPath on native platforms
        return response.response ?? outputPath;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message ?? 'Failed to merge PDFs',
        );
        return null;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to merge PDFs: $e',
      );
      return null;
    }
  }

  /// Legacy API kept for compatibility – returns dummy bytes but uses the real
  /// merge internally. Prefer [mergeSelectedPdfsToFile] in new code.
  Future<Uint8List?> mergeSelectedPdfs() async {
    final path = await mergeSelectedPdfsToFile();
    if (path != null) {
      // We already saved the file; in this app we care about the file path,
      // not raw bytes. Returning an empty Uint8List just to keep signature.
      return Uint8List(0);
    }
    return null;
  }

  // -----------------------------
  // Placeholders for future tools
  // (still stubs – we can implement later if you want)
  // -----------------------------
  Future<Uint8List?> splitPdf(
      String filePath, {
        int startPage = 1,
        int endPage = 1,
      }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO: implement real split logic
      await Future.delayed(const Duration(milliseconds: 400));
      state = state.copyWith(isLoading: false);
      return Uint8List(0);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to split PDF: $e',
        isLoading: false,
      );
      return null;
    }
  }

  Future<Uint8List?> compressPdf(
      String filePath, {
        int quality = 50,
      }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO: implement real compression logic
      await Future.delayed(const Duration(milliseconds: 400));
      state = state.copyWith(isLoading: false);
      return Uint8List(0);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to compress PDF: $e',
        isLoading: false,
      );
      return null;
    }
  }

  // -----------------------------
  // Utility
  // -----------------------------
  void reset() {
    state = const PdfState();
  }
}

extension on MergeMultiplePDFResponse {
  get response => null;
}

// Provider instance
  final pdfProvider =
    StateNotifierProvider<PdfProvider, PdfState>((ref) {
      return PdfProvider();
});
