import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:pdf_lab_pro/services/activity_tracker.dart';
import 'package:pdf_lab_pro/services/pdf_merge_service.dart';

class ImageToPdfState {
  final bool isLoading;
  final String? error;
  final String? success;
  final List<String> selectedImages;
  final List<Map<String, dynamic>> imageInfo;
  final String? convertedFilePath;
  final bool isConverting;
  final int progress;
  final int imageQuality;
  final bool reduceFileSize;

  const ImageToPdfState({
    this.isLoading = false,
    this.error,
    this.success,
    this.selectedImages = const [],
    this.imageInfo = const [],
    this.convertedFilePath,
    this.isConverting = false,
    this.progress = 0,
    this.imageQuality = 85,
    this.reduceFileSize = false,
  });

  ImageToPdfState copyWith({
    bool? isLoading,
    String? error,
    String? success,
    List<String>? selectedImages,
    List<Map<String, dynamic>>? imageInfo,
    String? convertedFilePath,
    bool? isConverting,
    int? progress,
    int? imageQuality,
    bool? reduceFileSize,
  }) {
    return ImageToPdfState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success,
      selectedImages: selectedImages ?? this.selectedImages,
      imageInfo: imageInfo ?? this.imageInfo,
      convertedFilePath: convertedFilePath ?? this.convertedFilePath,
      isConverting: isConverting ?? this.isConverting,
      progress: progress ?? this.progress,
      imageQuality: imageQuality ?? this.imageQuality,
      reduceFileSize: reduceFileSize ?? this.reduceFileSize,
    );
  }
}

class ImageToPdfProvider extends Notifier<ImageToPdfState> {
  late PdfMergeService _pdfMergeService;

  @override
  ImageToPdfState build() {
    _pdfMergeService = PdfMergeService();
    return const ImageToPdfState();
  }

  /// Select images
  Future<void> selectImages(List<String> imagePaths) async {
    try {
      state = state.copyWith(
        isLoading: true,
        error: null,
        success: null,
      );

      final newImageInfo = <Map<String, dynamic>>[];

      for (final path in imagePaths) {
        if (!state.selectedImages.contains(path)) {
          final file = File(path);
          final stat = await file.stat();
          final extension = p.extension(path).toLowerCase();

          newImageInfo.add({
            'path': path,
            'name': p.basename(path),
            'size': stat.size,
            'formattedSize': _formatFileSize(stat.size),
            'extension': extension,
            'type': _getFileType(extension),
            'dimensions': await _getImageDimensions(path),
          });
        }
      }

      state = state.copyWith(
        isLoading: false,
        selectedImages: [...state.selectedImages, ...imagePaths],
        imageInfo: [...state.imageInfo, ...newImageInfo],
        success: 'Added ${imagePaths.length} image(s)',
        convertedFilePath: null,
      );

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to add images: $e',
      );
    }
  }

  /// Remove an image
  void removeImage(String imagePath) {
    final newImages = state.selectedImages.where((path) => path != imagePath).toList();
    final newInfo = state.imageInfo.where((info) => info['path'] != imagePath).toList();

    state = state.copyWith(
      selectedImages: newImages,
      imageInfo: newInfo,
      convertedFilePath: null,
    );
  }

  /// Reorder images
  void reorderImages(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.selectedImages.length ||
        newIndex < 0 || newIndex >= state.selectedImages.length) {
      return;
    }

    final newImages = List<String>.from(state.selectedImages);
    final newInfo = List<Map<String, dynamic>>.from(state.imageInfo);

    final image = newImages.removeAt(oldIndex);
    final info = newInfo.removeAt(oldIndex);

    newImages.insert(newIndex, image);
    newInfo.insert(newIndex, info);

    state = state.copyWith(
      selectedImages: newImages,
      imageInfo: newInfo,
      convertedFilePath: null,
    );
  }

  /// Set image quality
  void setImageQuality(int quality) {
    state = state.copyWith(
      imageQuality: quality.clamp(10, 100),
    );
  }

  /// Toggle file size reduction
  void setReduceFileSize(bool value) {
    state = state.copyWith(
      reduceFileSize: value,
      imageQuality: value ? 75 : 85,
    );
  }

  /// Convert images to PDF
  Future<String?> convertToPdf() async {
    if (state.selectedImages.isEmpty) {
      state = state.copyWith(
        error: 'Please select at least 1 image',
        success: null,
      );
      return null;
    }

    state = state.copyWith(
      isConverting: true,
      progress: 0,
      error: null,
      success: null,
      convertedFilePath: null,
    );

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputName = 'converted_$timestamp.pdf';

      String pdfPath;

      if (state.reduceFileSize) {
        // Use custom compression
        pdfPath = await _convertImagesToPdfWithCompression(
          imagePaths: state.selectedImages,
          outputName: outputName,
          quality: state.imageQuality,
          onProgress: (progress) {
            state = state.copyWith(progress: progress);
          },
        );
      } else {
        // Use existing merge service (no compression)
        pdfPath = await _pdfMergeService.mergePdfsWithImages(
          filePaths: state.selectedImages,
          outputFileName: outputName,
        );
      }

      state = state.copyWith(
        isConverting: false,
        progress: 100,
        success: 'Successfully converted ${state.selectedImages.length} images to PDF'
            '${state.reduceFileSize ? ' (Compressed)' : ''}',
        convertedFilePath: pdfPath,
      );

      // Log the activity
      await ActivityTracker.logActivity(
        type: ActivityType.imageToPdf,
        title: 'Images to PDF',
        description: 'Converted ${state.selectedImages.length} images to PDF',
        filePath: pdfPath,
        extraData: {
          'imageCount': state.selectedImages.length,
          'compressed': state.reduceFileSize,
          'quality': state.imageQuality,
        },
      );
      return pdfPath;

    } catch (e) {
      state = state.copyWith(
        isConverting: false,
        progress: 0,
        error: '❌ Conversion failed: ${e.toString()}',
        convertedFilePath: null,
      );
      return null;
    }
  }
    // Add this method to the provider:
  /// Get size estimate for compression
  Map<String, dynamic> getSizeEstimate() {
    if (!state.reduceFileSize || state.selectedImages.isEmpty) {
      return {'estimate': 'Original image quality will be preserved'};
    }

    // Calculate total size
    int totalSize = 0;
    for (final path in state.selectedImages) {
      final file = File(path);
      if (file.existsSync()) {
        totalSize += file.lengthSync();
      }
    }

    if (totalSize == 0) {
      return {'estimate': 'Unable to calculate size estimate'};
    }

    // Calculate reduction based on quality
    final reduction = _calculateReductionPercentage(state.imageQuality);
    final estimatedSize = (totalSize * (100 - reduction) / 100).toInt();

    return {
      'estimate': 'PDF size reduced by ~$reduction% '
          '(${_formatSize(estimatedSize)} estimated)',
      'originalSize': totalSize,
      'estimatedSize': estimatedSize,
      'reduction': reduction,
    };
  }

  int _calculateReductionPercentage(int quality) {
    if (quality <= 40) return 75;
    if (quality <= 70) return 50;
    if (quality <= 90) return 30;
    return 10;
  }

  // Add this method to ImageToPdfProvider class (lib/providers/image_to_pdf_provider.dart)
  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB'];
    final i = (log(bytes) / log(1024)).floor();

    if (i == 0) return '$bytes ${suffixes[i]}';
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Convert images to PDF with compression
  Future<String> _convertImagesToPdfWithCompression({
    required List<String> imagePaths,
    required String outputName,
    required int quality,
    required Function(int) onProgress,
  }) async {
    final pdf = pw.Document();

    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      try {
        final file = File(imagePath);
        final imageBytes = await file.readAsBytes();

        // Compress image
        final compressedImage = await _compressImage(imageBytes, quality);
        final pdfImage = pw.MemoryImage(compressedImage);

        // Add page to PDF
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              );
            },
          ),
        );

        // Update progress
        final progress = ((i + 1) / imagePaths.length * 100).toInt();
        onProgress(progress);

      } catch (e) {
        // Add error page if image fails
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Text('Error loading image ${i + 1}'),
              );
            },
          ),
        );
      }
    }

    // Save PDF
    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(tempDir.path, outputName);

    final pdfBytes = await pdf.save();
    await File(outputPath).writeAsBytes(pdfBytes);

    return outputPath;
  }

  /// Compress image
  Future<Uint8List> _compressImage(Uint8List originalBytes, int quality) async {
    try {
      // Decode image
      final image = img.decodeImage(originalBytes);
      if (image == null) return originalBytes;

      // Calculate target dimensions based on quality
      final reductionFactor = (100 - quality) / 100.0;
      final targetWidth = (image.width * (1 - reductionFactor * 0.5)).toInt();
      final targetHeight = (image.height * (1 - reductionFactor * 0.5)).toInt();

      // Ensure minimum dimensions
      final finalWidth = targetWidth.clamp(300, image.width);
      final finalHeight = targetHeight.clamp(300, image.height);

      // Resize image
      final resizedImage = img.copyResize(
        image,
        width: finalWidth,
        height: finalHeight,
      );

      // Compress as JPEG with quality setting
      return img.encodeJpg(resizedImage, quality: quality);

    } catch (e) {
      // Image compression failed, returning original bytes.
      return originalBytes;
    }
  }

  /// Save PDF to app directory
  Future<File?> savePdf() async {
    if (state.convertedFilePath == null) return null;

    try {
      final file = File(state.convertedFilePath!);
      if (await file.exists()) {
        final savedFile = await _pdfMergeService.saveToAppDirectory(
          state.convertedFilePath!,
          customName: 'converted_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        return savedFile;
      }
    } catch (e) {
      // Error is handled gracefully
    }
    return null;
  }

  /// Reset everything
  void reset() {
    state = const ImageToPdfState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear success
  void clearSuccess() {
    state = state.copyWith(success: null);
  }

  // Helper methods
  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB'];
    final i = (bytes == 0) ? 0 : (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  String _getFileType(String extension) {
    final ext = extension.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp'].contains(ext)) {
      return 'Image';
    }
    return 'File';
  }

  Future<Map<String, int>> _getImageDimensions(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      return {
        'width': image?.width ?? 0,
        'height': image?.height ?? 0,
      };
    } catch (e) {
      return {'width': 0, 'height': 0};
    }
  }
}

final imageToPdfProvider = NotifierProvider<ImageToPdfProvider, ImageToPdfState>(
  ImageToPdfProvider.new,
);
