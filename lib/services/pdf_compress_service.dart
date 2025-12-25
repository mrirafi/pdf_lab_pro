// lib/services/pdf_compress_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_lab_pro/models/compress_model.dart';

class PdfCompressService {
  /// Main compression method - smart detection and optimization
  Future<Map<String, dynamic>> compressPdf({
    required String pdfPath,
    required CompressionLevel compressionLevel,
    required bool downscaleImages,
    required int imageQuality,
    required String fileName,
  }) async {
    try {
      // 1. Analyze PDF first
      final analysis = await _analyzePdf(pdfPath);

      // 2. Choose compression strategy based on analysis
      final strategy = _chooseCompressionStrategy(
        analysis,
        compressionLevel,
      );

      // 3. Apply compression
      String compressedPath;
      if (strategy == CompressionStrategy.recreate) {
        compressedPath = await _recreatePdfWithCompression(
          pdfPath,
          compressionLevel,
          downscaleImages,
          imageQuality,
          fileName,
        );
      } else {
        compressedPath = await _directCompression(
          pdfPath,
          compressionLevel,
          fileName,
        );
      }

      // 4. Verify result
      final originalFile = File(pdfPath);
      final compressedFile = File(compressedPath);
      final originalSize = await originalFile.length();
      final compressedSize = await compressedFile.length();
      final ratio = (1 - compressedSize / originalSize) * 100;

      return {
        'path': compressedPath,
        'originalSize': originalSize,
        'compressedSize': compressedSize,
        'compressionRatio': ratio,
        'strategy': strategy.toString(),
      };
    } catch (e) {
      throw Exception('Compression failed: $e');
    }
  }

  /// Analyze PDF to determine best compression approach
  Future<Map<String, dynamic>> _analyzePdf(String pdfPath) async {
    try {
      final file = File(pdfPath);
      final size = await file.length();
      final pdfBytes = await file.readAsBytes();

      // Quick analysis without full parsing
      final pdfString = String.fromCharCodes(pdfBytes.take(10000));

      // Detect images in PDF
      bool hasImages = pdfString.contains('/XObject') ||
          pdfString.contains('/Image') ||
          (pdfString.contains('stream') && pdfString.contains('endstream'));

      // Detect scanned PDF (image-based)
      bool isScanned = hasImages && !pdfString.contains('/Font');

      // Estimate pages based on size
      int estimatedPages = max(1, (size / (150 * 1024)).ceil());

      return {
        'size': size,
        'hasImages': hasImages,
        'isScanned': isScanned,
        'estimatedPages': estimatedPages,
        'sizeCategory': _getSizeCategory(size),
      };
    } catch (e) {
      // Fallback analysis
      final file = File(pdfPath);
      final size = await file.length();
      return {
        'size': size,
        'hasImages': true,
        'isScanned': true,
        'estimatedPages': max(1, (size / (200 * 1024)).ceil()),
        'sizeCategory': _getSizeCategory(size),
      };
    }
  }

  String _getSizeCategory(int size) {
    if (size < 500 * 1024) return 'small';
    if (size < 5 * 1024 * 1024) return 'medium';
    if (size < 20 * 1024 * 1024) return 'large';
    return 'very_large';
  }

  CompressionStrategy _chooseCompressionStrategy(
      Map<String, dynamic> analysis,
      CompressionLevel level,
      ) {
    final sizeCategory = analysis['sizeCategory'] as String;
    final hasImages = analysis['hasImages'] as bool;

    // Always recreate for PDFs with images (to compress them)
    if (hasImages) {
      return CompressionStrategy.recreate;
    }

    // For text-only PDFs, use direct compression for minimal/light levels
    if (sizeCategory == 'small' &&
        (level == CompressionLevel.minimal || level == CompressionLevel.light)) {
      return CompressionStrategy.direct;
    }

    // For larger text PDFs or higher compression levels, recreate
    return CompressionStrategy.recreate;
  }

  /// Direct compression - keeps original structure (for text-only PDFs)
  Future<String> _directCompression(
      String pdfPath,
      CompressionLevel level,
      String fileName,
      ) async {
    final file = File(pdfPath);
    final pdfBytes = await file.readAsBytes();

    // Simple byte-level optimization
    final optimizedBytes = await _optimizePdfBytes(pdfBytes, level);

    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tempDir.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}_$fileName',
    );

    await File(outputPath).writeAsBytes(optimizedBytes);
    return outputPath;
  }

  /// Recreate PDF with image optimization
  Future<String> _recreatePdfWithCompression(
      String pdfPath,
      CompressionLevel level,
      bool downscaleImages,
      int imageQuality,
      String fileName,
      ) async {
    try {
      final pdfBytes = await File(pdfPath).readAsBytes();
      final pdf = pw.Document();

      // Get pages using printing package
      final pages = Printing.raster(pdfBytes, dpi: 150.0);
      int pageIndex = 0;

      await for (final page in pages) {
        pageIndex++;

        // Convert page to image
        final pageImage = await page.toPng();

        // Optimize image based on settings
        final optimizedImage = await _optimizeImage(
          pageImage,
          level,
          downscaleImages,
          imageQuality,
        );

        final pdfImage = pw.MemoryImage(optimizedImage);

        // Add to new PDF
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(
                  pdfImage,
                  width: PdfPageFormat.a4.width,
                  height: PdfPageFormat.a4.height,
                  fit: pw.BoxFit.contain,
                ),
              );
            },
          ),
        );
      }

      // Save compressed PDF
      final compressedBytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final outputPath = p.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );

      await File(outputPath).writeAsBytes(compressedBytes);
      return outputPath;
    } catch (e) {
      // Fallback to direct compression
      return await _directCompression(pdfPath, level, fileName);
    }
  }

  /// Smart image optimization
  Future<Uint8List> _optimizeImage(
      Uint8List originalImage,
      CompressionLevel level,
      bool downscaleImages,
      int imageQuality,
      ) async {
    final image = img.decodeImage(originalImage);
    if (image == null) return originalImage;

    // Calculate target quality based on level
    int targetQuality;
    switch (level) {
      case CompressionLevel.minimal:
        targetQuality = 95; // Near perfect
        break;
      case CompressionLevel.light:
        targetQuality = 88; // Excellent
        break;
      case CompressionLevel.moderate:
        targetQuality = 75; // Good
        break;
      case CompressionLevel.aggressive:
        targetQuality = 65; // Acceptable
        break;
      case CompressionLevel.custom:
        targetQuality = imageQuality;
        break;
    }

    // Apply controlled compression
    img.Image optimizedImage = image;

    if (downscaleImages) {
      final targetWidth = _getTargetWidth(level, image.width);
      optimizedImage = img.copyResize(
        optimizedImage,
        width: targetWidth,
      );
    }

    // Convert to JPEG with controlled quality
    return img.encodeJpg(optimizedImage, quality: targetQuality);
  }

  int _getTargetWidth(CompressionLevel level, int originalWidth) {
    switch (level) {
      case CompressionLevel.minimal:
        return (originalWidth * 0.98).toInt(); // Just 2% reduction
      case CompressionLevel.light:
        return (originalWidth * 0.92).toInt(); // 8% reduction
      case CompressionLevel.moderate:
        return (originalWidth * 0.8).toInt();  // 20% reduction
      case CompressionLevel.aggressive:
        return (originalWidth * 0.65).toInt(); // 35% reduction
      case CompressionLevel.custom:
        return (originalWidth * 0.8).toInt();
    }
  }

  /// Simple PDF byte optimization
  Future<Uint8List> _optimizePdfBytes(
      Uint8List pdfBytes,
      CompressionLevel level,
      ) async {
    // For now, return original - implement real optimization later
    // This could include removing metadata, optimizing streams, etc.
    return pdfBytes;
  }
}