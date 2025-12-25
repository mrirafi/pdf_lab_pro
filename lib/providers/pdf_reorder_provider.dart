import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_lab_pro/services/activity_tracker.dart';
import 'package:pdf_lab_pro/services/pdf_reorder_service.dart';

class ReorderPagesState {
  final bool isLoading;
  final String? error;
  final String? success;
  final String? pdfPath;
  final String? pdfName;
  final List<Uint8List> pageThumbnails;
  final List<int> currentOrder;
  final String? reorderedFilePath;
  final int? pageCount;

  const ReorderPagesState({
    this.isLoading = false,
    this.error,
    this.success,
    this.pdfPath,
    this.pdfName,
    this.pageThumbnails = const [],
    this.currentOrder = const [],
    this.reorderedFilePath,
    this.pageCount,
  });

  ReorderPagesState copyWith({
    bool? isLoading,
    String? error,
    String? success,
    String? pdfPath,
    String? pdfName,
    List<Uint8List>? pageThumbnails,
    List<int>? currentOrder,
    String? reorderedFilePath,
    int? pageCount,
  }) {
    return ReorderPagesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfName: pdfName ?? this.pdfName,
      pageThumbnails: pageThumbnails ?? this.pageThumbnails,
      currentOrder: currentOrder ?? this.currentOrder,
      reorderedFilePath: reorderedFilePath ?? this.reorderedFilePath,
      pageCount: pageCount ?? this.pageCount,
    );
  }
}

class PdfReorderProvider extends Notifier<ReorderPagesState> {
  late PdfReorderService _reorderService;

  @override
  ReorderPagesState build() {
    _reorderService = PdfReorderService();
    return const ReorderPagesState();
  }

  /// Load PDF and extract pages
  Future<void> loadPdf(String pdfPath) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      success: null,
      reorderedFilePath: null,
    );

    try {
      // Get PDF info
      final pdfInfo = await _reorderService.getPdfInfo(pdfPath);

      // Get page thumbnails
      final thumbnails = await _reorderService.getPdfPageThumbnails(pdfPath);

      // Create initial order (0, 1, 2, ...)
      final initialOrder = List<int>.generate(thumbnails.length, (index) => index);

      state = state.copyWith(
        isLoading: false,
        pdfPath: pdfPath,
        pdfName: pdfInfo['name'],
        pageThumbnails: thumbnails,
        currentOrder: initialOrder,
        pageCount: thumbnails.length,
        success: 'Loaded ${thumbnails.length} pages',
      );

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load PDF: $e',
      );
    }
  }

  /// Reorder pages
  void reorderPages(int oldIndex, int newIndex) {
    final newOrder = List<int>.from(state.currentOrder);

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final pageId = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, pageId);

    state = state.copyWith(
      currentOrder: newOrder,
    );
  }

  /// Apply reordering and save new PDF
  Future<void> applyReorder() async {
    if (state.pdfPath == null || state.currentOrder.isEmpty) {
      state = state.copyWith(
        error: 'No PDF loaded or no pages to reorder',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      success: null,
    );

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputName = 'reordered_$timestamp.pdf';

      final reorderedPath = await _reorderService.reorderPages(
        pdfPath: state.pdfPath!,
        newOrder: state.currentOrder,
        outputFileName: outputName,
      );

      state = state.copyWith(
        isLoading: false,
        reorderedFilePath: reorderedPath,
        success: 'Pages reordered successfully!',
      );

// Log the activity
      await ActivityTracker.logActivity(
        type: ActivityType.reorder,
        title: 'Reordered PDF',
        description: 'Reordered ${state.pageThumbnails.length} pages',
        filePath: reorderedPath,
        extraData: {
          'pageCount': state.pageThumbnails.length,
        },
      );

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to reorder pages: $e',
      );
    }
  }

  /// Reset to original order
  void resetOrder() {
    final originalOrder = List<int>.generate(state.pageThumbnails.length, (index) => index);
    state = state.copyWith(
      currentOrder: originalOrder,
      success: 'Order reset to original',
    );
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear success message
  void clearSuccess() {
    state = state.copyWith(success: null);
  }

  /// Reset everything
  void reset() {
    state = const ReorderPagesState();
  }
}

final pdfReorderProvider = NotifierProvider<PdfReorderProvider, ReorderPagesState>(
  PdfReorderProvider.new,
);
