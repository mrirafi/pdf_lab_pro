import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_lab_pro/services/activity_tracker.dart';
import 'package:pdf_lab_pro/services/pdf_split_service.dart';
import 'package:pdf_lab_pro/utils/file_utils.dart';

class PdfSplitState {
  final bool isLoading;
  final String? error;
  final String? success;
  final String? pdfPath;
  final String? pdfName;
  final int? pageCount;
  final int? originalSize;
  final SplitMode splitMode;
  final String pageRangeInput;
  final int nValue;
  final List<String> outputFiles;
  final List<String> outputFileNames;

  const PdfSplitState({
    this.isLoading = false,
    this.error,
    this.success,
    this.pdfPath,
    this.pdfName,
    this.pageCount,
    this.originalSize,
    this.splitMode = SplitMode.pageRange,
    this.pageRangeInput = '',
    this.nValue = 2,
    this.outputFiles = const [],
    this.outputFileNames = const [],
  });

  PdfSplitState copyWith({
    bool? isLoading,
    String? error,
    String? success,
    String? pdfPath,
    String? pdfName,
    int? pageCount,
    int? originalSize,
    SplitMode? splitMode,
    String? pageRangeInput,
    int? nValue,
    List<String>? outputFiles,
    List<String>? outputFileNames,
  }) {
    return PdfSplitState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfName: pdfName ?? this.pdfName,
      pageCount: pageCount ?? this.pageCount,
      originalSize: originalSize ?? this.originalSize,
      splitMode: splitMode ?? this.splitMode,
      pageRangeInput: pageRangeInput ?? this.pageRangeInput,
      nValue: nValue ?? this.nValue,
      outputFiles: outputFiles ?? this.outputFiles,
      outputFileNames: outputFileNames ?? this.outputFileNames,
    );
  }

  bool get hasValidPageRange {
    if (pageCount == null || pageRangeInput.isEmpty) return false;
    return PageRangeParser.isValidRange(pageRangeInput, pageCount!);
  }

  String get formattedOriginalSize {
    if (originalSize == null || originalSize! <= 0) return '0 B';
    return FileUtils.formatFileSize(originalSize!);
  }

  String get exampleText {
    if (pageCount == null) return 'e.g., 1-3, 5, 7-9';
    return 'e.g., 1-3, 5, 7-9 (1-$pageCount)';
  }
}

class PdfSplitProvider extends Notifier<PdfSplitState> {
  late PdfSplitService _service;

  @override
  PdfSplitState build() {
    _service = PdfSplitService();
    return const PdfSplitState();
  }

  /// Select PDF file
  Future<void> selectPdf(String filePath) async {
    try {
      state = state.copyWith(
        isLoading: true,
        error: null,
        success: null,
        outputFiles: [],
        outputFileNames: [],
      );

      final info = await _service.getPdfInfo(filePath);

      state = state.copyWith(
        isLoading: false,
        pdfPath: filePath,
        pdfName: info['name'],
        pageCount: info['pageCount'],
        originalSize: info['size'],
        success: '✅ Loaded ${info['name']} (${info['pageCount']} pages)',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '❌ Failed to load PDF: $e',
      );
    }
  }

  /// Set split mode
  void setSplitMode(SplitMode mode) {
    state = state.copyWith(
      splitMode: mode,
      error: null,
      success: null,
    );
  }

  /// Update page range input
  void setPageRangeInput(String input) {
    state = state.copyWith(
      pageRangeInput: input,
      error: null,
    );
  }

  /// Update N value for "Every N Pages" mode
  void setNValue(int value) {
    final clampedValue = value.clamp(2, state.pageCount ?? 100);
    state = state.copyWith(
      nValue: clampedValue,
      error: null,
    );
  }

  /// Execute split operation
  Future<void> splitPdf() async {
    if (state.pdfPath == null) {
      state = state.copyWith(error: 'Please select a PDF file first');
      return;
    }

    if (state.pageCount == null || state.pageCount! < 1) {
      state = state.copyWith(error: 'Invalid PDF file');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      success: null,
      outputFiles: [],
      outputFileNames: [],
    );

    try {
      List<String> outputFiles;
      final baseName = state.pdfName?.replaceAll('.pdf', '') ?? 'split';

      switch (state.splitMode) {
        case SplitMode.pageRange:
          if (!state.hasValidPageRange) {
            throw Exception('Invalid page range format');
          }
          final ranges = PageRangeParser.parseRanges(
            state.pageRangeInput,
            state.pageCount!,
          );
          outputFiles = await _service.splitByRanges(
            pdfPath: state.pdfPath!,
            ranges: ranges,
            baseName: baseName,
          );
          break;

        case SplitMode.everyNPages:
          if (state.nValue < 2 || state.nValue > state.pageCount!) {
            throw Exception('N must be between 2 and ${state.pageCount}');
          }
          outputFiles = await _service.splitEveryNPages(
            pdfPath: state.pdfPath!,
            n: state.nValue,
            baseName: baseName,
          );
          break;

        case SplitMode.singlePages:
          outputFiles = await _service.splitIntoSinglePages(
            pdfPath: state.pdfPath!,
            baseName: baseName,
          );
          break;
      }

      final outputFileNames = outputFiles.map((path) => path.split('/').last).toList();

      state = state.copyWith(
        isLoading: false,
        success: '✅ Successfully created ${outputFiles.length} file(s)',
        outputFiles: outputFiles,
        outputFileNames: outputFileNames,
      );

      // In the splitPdf method, after successful split:
      final ranges = await _service.splitByRanges(
        pdfPath: state.pdfPath!,
        ranges: PageRangeParser.parseRanges(
          state.pageRangeInput,
          state.pageCount!,
        ),
        baseName: baseName,
      );

// Log the activity
      await ActivityTracker.logActivity(
        type: ActivityType.split,
        title: 'Split PDF',
        description: 'Split into ${outputFiles.length} parts',
        filePath: outputFiles.isNotEmpty ? outputFiles.first : null,
        extraData: {
          'partsCount': outputFiles.length,
          'pageCount': state.pageCount,
          'splitMode': state.splitMode.label,
        },
      );

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '❌ Split failed: ${e.toString()}',
        outputFiles: [],
        outputFileNames: [],
      );
    }
  }

  /// Reset everything
  void reset() {
    state = const PdfSplitState();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear success message
  void clearSuccess() {
    state = state.copyWith(success: null);
  }
}

final pdfSplitProvider = NotifierProvider<PdfSplitProvider, PdfSplitState>(
  PdfSplitProvider.new,
);