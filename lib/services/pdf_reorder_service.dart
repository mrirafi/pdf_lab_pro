import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;

class PdfReorderService {
  /// Get all pages from a PDF file
  Future<List<Uint8List>> getPdfPageThumbnails(String pdfPath) async {
    final List<Uint8List> thumbnails = [];

    try {
      final pdfBytes = await File(pdfPath).readAsBytes();

      // Use printing package to get pages for thumbnails only
      final pageStream = Printing.raster(pdfBytes, dpi: 72.0);

      await for (final page in pageStream) {
        try {
          // Generate thumbnail for the page (low quality for preview)
          final thumbnailBytes = await page.toPng();
          thumbnails.add(thumbnailBytes);
        } catch (e) {
          // Add placeholder for failed thumbnails
          thumbnails.add(_createPlaceholderImage());
        }
      }

      return thumbnails;
    } catch (e) {
      throw Exception('Failed to read PDF pages: $e');
    }
  }

  /// Get PDF page count
  Future<int> getPdfPageCount(String pdfPath) async {
    try {
      final pdfBytes = await File(pdfPath).readAsBytes();
      final pages = Printing.raster(pdfBytes, dpi: 72.0);
      int pageCount = 0;
      await for (final _ in pages) {
        pageCount++;
      }
      return pageCount;
    } catch (e) {
      // Fallback: estimate based on file size
      final file = File(pdfPath);
      final fileSize = await file.length();
      final estimatedPages = (fileSize / (100 * 1024)).ceil();
      return estimatedPages.clamp(1, 1000);
    }
  }

  /// Reorder pages using the pdf package to preserve original formatting
  Future<String> reorderPages({
    required String pdfPath,
    required List<int> newOrder,
    required String outputFileName,
  }) async {
    try {
      final pdfBytes = await File(pdfPath).readAsBytes();

      // Create a new PDF document
      final pdf = pw.Document();

      // First, let's try to use the pdf package to preserve formatting
      // Note: The pdf package doesn't have direct page extraction
      // We'll use a different approach

      // Method: Extract each page as image and re-add them
      // This preserves content but not vector formatting
      await _reorderPagesAsImages(pdf, pdfBytes, newOrder);

      // Save the reordered PDF
      final tempDir = await getTemporaryDirectory();
      final outputPath = p.join(tempDir.path, outputFileName);

      final reorderedBytes = await pdf.save();
      await File(outputPath).writeAsBytes(reorderedBytes);

      return outputPath;
    } catch (e) {
      throw Exception('Failed to reorder pages: $e');
    }
  }

  /// Reorder pages by converting to images (preserves visual content)
  Future<void> _reorderPagesAsImages(
      pw.Document pdf,
      Uint8List pdfBytes,
      List<int> newOrder
      ) async {
    try {
      // Get all pages as high-quality images
      final pages = Printing.raster(pdfBytes, dpi: 150.0);
      final List<Uint8List> pageImages = [];

      // Convert all pages to images
      await for (final page in pages) {
        try {
          final pngBytes = await page.toPng();
          pageImages.add(pngBytes);
        } catch (e) {
          // Add placeholder for failed pages
          pageImages.add(_createPlaceholderImage());
        }
      }

      // Validate new order
      if (newOrder.length != pageImages.length) {
        throw Exception('New order must include all ${pageImages.length} pages');
      }

      // Create new PDF in new order
      for (final pageIndex in newOrder) {
        if (pageIndex < 0 || pageIndex >= pageImages.length) {
          throw Exception('Invalid page index: $pageIndex');
        }

        final pageImage = pageImages[pageIndex];
        final pdfImage = pw.MemoryImage(pageImage);

        // Try to preserve original page size
        try {
          // Get original page info (estimate)
          final originalPage = await _getPageInfo(pdfBytes, pageIndex);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(
                originalPage['width'] ?? PdfPageFormat.a4.width,
                originalPage['height'] ?? PdfPageFormat.a4.height,
              ),
              build: (pw.Context context) {
                return pw.Image(pdfImage);
              },
            ),
          );
        } catch (e) {
          // Fallback to A4 if can't get original size
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Image(pdfImage),
                );
              },
            ),
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to create reordered PDF: $e');
    }
  }

  /// Get page info (size)
  Future<Map<String, double>> _getPageInfo(Uint8List pdfBytes, int pageIndex) async {
    try {
      // Use printing package to get page dimensions
      final pages = Printing.raster(pdfBytes, dpi: 72.0);
      int currentIndex = 0;

      await for (final page in pages) {
        if (currentIndex == pageIndex) {
          return {
            'width': page.width.toDouble(),
            'height': page.height.toDouble(),
          };
        }
        currentIndex++;
      }

      // Default to A4 if not found
      return {
        'width': PdfPageFormat.a4.width,
        'height': PdfPageFormat.a4.height,
      };
    } catch (e) {
      // Default to A4
      return {
        'width': PdfPageFormat.a4.width,
        'height': PdfPageFormat.a4.height,
      };
    }
  }

  /// Create placeholder image for failed pages
  Uint8List _createPlaceholderImage() {
    // Create a simple placeholder image
    final width = 200;
    final height = 300;

    final image = img.Image(width: width, height: height);

    // Fill with light gray
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixel(x, y, img.ColorRgb8(240, 240, 240));
      }
    }

    // Add placeholder text
    img.drawString(
      image,
      'Page',
      font: img.arial24,
      x: width ~/ 2 - 25,
      y: height ~/ 2 - 12,
      color: img.ColorRgb8(150, 150, 150),
    );

    return img.encodePng(image);
  }

  /// Get PDF info
  Future<Map<String, dynamic>> getPdfInfo(String pdfPath) async {
    try {
      final file = File(pdfPath);
      final stat = await file.stat();
      final pageCount = await getPdfPageCount(pdfPath);

      return {
        'path': pdfPath,
        'name': p.basename(pdfPath),
        'size': stat.size,
        'pageCount': pageCount,
        'modified': stat.modified,
      };
    } catch (e) {
      throw Exception('Failed to get PDF info: $e');
    }
  }
}