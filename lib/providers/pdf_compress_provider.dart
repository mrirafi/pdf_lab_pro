// lib/providers/pdf_compress_provider.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_lab_pro/models/compress_model.dart';
import 'package:pdf_lab_pro/services/activity_tracker.dart';
import 'package:pdf_lab_pro/services/pdf_compress_service.dart'; // Use shared model

class PdfCompressState {
  final bool isLoading;
  final String? error;
  final String? success;
  final String? pdfPath;
  final String? pdfName;
  final int originalSize;
  final int? compressedSize;
  final double? compressionRatio;
  final CompressionLevel compressionLevel;
  final bool downscaleImages;
  final int imageQuality;
  final String? compressedFilePath;

  const PdfCompressState({
    this.isLoading = false,
    this.error,
    this.success,
    this.pdfPath,
    this.pdfName,
    this.originalSize = 0,
    this.compressedSize,
    this.compressionRatio,
    this.compressionLevel = CompressionLevel.moderate,

    this.downscaleImages = true,
    this.imageQuality = 80,
    this.compressedFilePath,
  });

  PdfCompressState copyWith({
    bool? isLoading,
    String? error,
    String? success,
    String? pdfPath,
    String? pdfName,
    int? originalSize,
    int? compressedSize,
    double? compressionRatio,
    CompressionLevel? compressionLevel,
    bool? downscaleImages,
    int? imageQuality,
    String? compressedFilePath,
  }) {
    return PdfCompressState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfName: pdfName ?? this.pdfName,
      originalSize: originalSize ?? this.originalSize,
      compressedSize: compressedSize ?? this.compressedSize,
      compressionRatio: compressionRatio ?? this.compressionRatio,
      compressionLevel: compressionLevel ?? this.compressionLevel,
      downscaleImages: downscaleImages ?? this.downscaleImages,
      imageQuality: imageQuality ?? this.imageQuality,
      compressedFilePath: compressedFilePath ?? this.compressedFilePath,
    );
  }

  String get formattedOriginalSize {
    if (originalSize <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB'];
    final i = (log(originalSize) / log(1024)).floor();
    return '${(originalSize / pow(1024, i)).toStringAsFixed(i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  String get formattedCompressedSize {
    if (compressedSize == null || compressedSize! <= 0) return '--';
    const suffixes = ['B', 'KB', 'MB'];
    final i = (log(compressedSize!) / log(1024)).floor();
    return '${(compressedSize! / pow(1024, i)).toStringAsFixed(i > 0 ? 1 : 0)} ${suffixes[i]}';
  }
}

class PdfCompressProvider extends Notifier<PdfCompressState> {
  @override
  PdfCompressState build() {
    return const PdfCompressState();
  }

  Future<void> selectPdf(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        state = state.copyWith(
          error: 'File not found',
          success: null,
        );
        return;
      }

      final stat = await file.stat();
      state = state.copyWith(
        pdfPath: filePath,
        pdfName: file.path.split('/').last,
        originalSize: stat.size,
        error: null,
        success: 'File selected: ${file.path.split('/').last}',
        compressedSize: null,
        compressionRatio: null,
        compressedFilePath: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to select file: $e',
        success: null,
      );
    }
  }

  void setCompressionLevel(CompressionLevel level) {
    state = state.copyWith(
      compressionLevel: level,
      // Change this line:
      downscaleImages: level != CompressionLevel.minimal, // Minimal = no downscaling
      imageQuality: _getDefaultQuality(level),
    );
  }
  int _getDefaultQuality(CompressionLevel level) {
    switch (level) {
      case CompressionLevel.minimal: return 95;
      case CompressionLevel.light: return 88;
      case CompressionLevel.moderate: return 75;
      case CompressionLevel.aggressive: return 65;
      case CompressionLevel.custom: return 80;
    }
  }

  void setDownscaleImages(bool value) {
    state = state.copyWith(downscaleImages: value);
  }

  void setImageQuality(int quality) {
    state = state.copyWith(imageQuality: quality.clamp(10, 100));
  }

  Future<void> compressPdf() async {
    if (state.pdfPath == null) {
      state = state.copyWith(error: 'Please select a PDF file first');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      success: null,
      compressedFilePath: null,
    );

    try {
      final service = PdfCompressService();
      final result = await service.compressPdf(
        pdfPath: state.pdfPath!,
        compressionLevel: state.compressionLevel,
        downscaleImages: state.downscaleImages,
        imageQuality: state.imageQuality,
        fileName: state.pdfName ?? 'compressed',
      );

      final originalFile = File(state.pdfPath!);
      final originalSize = await originalFile.length();
      final compressedSize = await File(result['path']).length();
      final ratio = (1 - compressedSize / originalSize) * 100;

      state = state.copyWith(
        isLoading: false,
        success: '✅ Compressed successfully! '
            'Reduced by ${ratio.toStringAsFixed(1)}%',
        compressedSize: compressedSize,
        compressionRatio: ratio,
        compressedFilePath: result['path'],
      );

      // In the compressPdf method, after successful compression:
      final compressedFile = await service.compressPdf(
        pdfPath: state.pdfPath!,
        compressionLevel: state.compressionLevel,
        downscaleImages: state.downscaleImages,
        imageQuality: state.imageQuality,
        fileName: state.pdfName ?? 'compressed',
      );

// Log the activity
      await ActivityTracker.logActivity(
        type: ActivityType.compress,
        title: 'Compressed PDF',
        description: 'Reduced by ${ratio.toStringAsFixed(1)}%',
        filePath: result['path'],
        extraData: {
          'originalSize': state.originalSize,
          'compressedSize': compressedSize,
          'ratio': ratio,
          'level': state.compressionLevel.label,
        },
      );


    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '❌ Compression failed: ${e.toString()}',
        compressedFilePath: null,
      );
    }
  }

  void reset() {
    state = const PdfCompressState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clearSuccess() {
    state = state.copyWith(success: null);
  }
}

final pdfCompressProvider = NotifierProvider<PdfCompressProvider, PdfCompressState>(
  PdfCompressProvider.new,
);