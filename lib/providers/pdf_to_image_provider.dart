import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_lab_pro/services/activity_tracker.dart';
import 'package:pdf_lab_pro/services/pdf_to_image_service.dart';
import 'package:pdf_lab_pro/services/image_save_service.dart';

class PdfToImageState {
  final bool isLoading;
  final String status;
  final String? error;
  final List<String> images;
  final List<String> logs;
  final String pdfName;
  final int currentPage;
  final int totalPages;
  final Map<String, Uint8List?> thumbnails;

  PdfToImageState({
    this.isLoading = false,
    this.status = '',
    this.error,
    this.images = const [],
    this.logs = const [],
    this.pdfName = '',
    this.currentPage = 0,
    this.totalPages = 0,
    Map<String, Uint8List?>? thumbnails,
  }) : thumbnails = thumbnails ?? <String, Uint8List?>{};

  PdfToImageState copyWith({
    bool? isLoading,
    String? status,
    String? error,
    List<String>? images,
    List<String>? logs,
    String? pdfName,
    int? currentPage,
    int? totalPages,
    Map<String, Uint8List?>? thumbnails,
  }) {
    return PdfToImageState(
      isLoading: isLoading ?? this.isLoading,
      status: status ?? this.status,
      error: error ?? this.error,
      images: images ?? this.images,
      logs: logs ?? this.logs,
      pdfName: pdfName ?? this.pdfName,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      thumbnails: thumbnails ?? this.thumbnails,
    );
  }
}

class PdfToImageNotifier extends Notifier<PdfToImageState> {
  final PdfToImageService _service = PdfToImageService();
  final ImageSaveService _saveService = ImageSaveService();

  @override
  PdfToImageState build() {
    // Return initial state
    return PdfToImageState(
      status: 'Ready to convert PDF',
      logs: ['🔄 Provider initialized'],
    );
  }

  Future<void> convertPdfToImages({
    required String pdfPath,
    required String pdfName,
    required ImageQuality quality,
  }) async {
    try {
      // Reset state
      state = PdfToImageState(
        isLoading: true,
        status: 'Starting conversion...',
        pdfName: pdfName,
        logs: ['📱 Starting PDF to image conversion...'],
        thumbnails: <String, Uint8List?>{},
      );

      final images = await _service.convertPdfToImages(
        pdfPath: pdfPath,
        pdfName: pdfName,
        quality: quality,
        onProgress: (current, total) {
          state = state.copyWith(
            currentPage: current,
            totalPages: total,
            status: 'Converting page $current of $total...',
          );
        },
        onLog: (log) {
          final newLogs = List<String>.from(state.logs)..add(log);
          state = state.copyWith(logs: newLogs);
        },
      );

      // Generate thumbnails for all converted images
      final thumbnails = <String, Uint8List?>{};
      for (final imagePath in images) {
        final thumbnail = await PdfToImageService.generateThumbnail(imagePath);
        thumbnails[imagePath] = thumbnail;
      }

      state = state.copyWith(
        isLoading: false,
        images: images,
        thumbnails: thumbnails,
        status: images.isNotEmpty
            ? '✅ Successfully converted ${images.length} pages'
            : '❌ No images were generated',
        currentPage: 0,
        totalPages: 0,
      );

// Log the activity
      await ActivityTracker.logActivity(
        type: ActivityType.pdfToImage,
        title: 'PDF to Images',
        description: 'Converted to ${images.length} images',
        filePath: images.isNotEmpty ? images.first : null,
        extraData: {
          'imageCount': images.length,
          'quality': quality.label,
        },
      );

    } catch (e) {
      final errorLog = '❌ Error: ${e.toString()}';
      final newLogs = List<String>.from(state.logs)..add(errorLog);

      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        status: '❌ Conversion failed',
        logs: newLogs,
      );
    }
  }

  Future<void> downloadAllImages() async {
    if (state.images.isEmpty) {
      state = state.copyWith(error: 'No images to download');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      status: 'Downloading images...',
    );

    try {
      final savedCount = await _saveService.saveMultipleImages(
        imagePaths: state.images,
        baseName: state.pdfName,
      );

      state = state.copyWith(
        isLoading: false,
        status: savedCount > 0
            ? '✅ Successfully downloaded $savedCount image(s)'
            : '❌ No images were downloaded',
      );

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Download failed: $e',
        status: '❌ Download failed',
      );
    }
  }

  Future<void> downloadSingleImage(String imagePath) async {
    try {
      final success = await _saveService.saveImageToGallery(
        imagePath,
        '${state.pdfName}_page_${state.images.indexOf(imagePath) + 1}',
      );

      if (success) {
        state = state.copyWith(
          status: '✅ Image downloaded successfully',
        );
      } else {
        state = state.copyWith(
          status: '❌ Failed to download image',
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Download failed: $e',
        status: '❌ Download failed',
      );
    }
  }

  void clearImages() {
    try {
      // Delete temporary image files
      for (final imagePath in state.images) {
        try {
          final file = File(imagePath);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      }

      state = state.copyWith(
        images: [],
        thumbnails: <String, Uint8List?>{},
        status: 'Images cleared',
        logs: List<String>.from(state.logs)..add('🗑️ Images cleared from memory'),
      );
    } catch (e) {
      state = state.copyWith(
        status: 'Error clearing images',
        error: e.toString(),
      );
    }
  }

  void reset() {
    // Use ref.invalidateSelf() to reset to initial state
    ref.invalidateSelf();
  }

  void addLog(String log) {
    final newLogs = List<String>.from(state.logs)..add(log);
    state = state.copyWith(logs: newLogs);
  }
}

final pdfToImageProvider = NotifierProvider<PdfToImageNotifier, PdfToImageState>(
      () => PdfToImageNotifier(),
);
