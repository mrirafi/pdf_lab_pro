import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:pdf_lab_pro/utils/file_utils.dart';
import 'package:printing/printing.dart';

class PdfMergeService {
  /// Merge multiple PDFs into a single PDF
  Future<String> mergePdfs({
    required List<String> pdfPaths,
    required String outputFileName,
  }) async {
    try {
      if (pdfPaths.length < 2) {
        throw Exception('Select at least 2 PDF files to merge');
      }

      // Create the final PDF document
      final pdf = pw.Document();

      for (final pdfPath in pdfPaths) {
        final file = File(pdfPath);
        if (!await file.exists()) {
          throw Exception('File not found: $pdfPath');
        }

        // Read PDF file
        final pdfBytes = await file.readAsBytes();

        // Use printing package to convert PDF pages to images, then add to new PDF
        await _addPdfPagesAsImages(pdf, pdfPath);
      }

      // Save the merged PDF
      final tempDir = await getTemporaryDirectory();
      final outputPath = p.join(tempDir.path, outputFileName);

      final mergedBytes = await pdf.save();
      await File(outputPath).writeAsBytes(mergedBytes);

      return outputPath;
    } catch (e) {
      throw Exception('Failed to merge PDFs: $e');
    }
  }

  /// Merge PDFs with images
  Future<String> mergePdfsWithImages({
    required List<String> filePaths,
    required String outputFileName,
  }) async {
    try {
      if (filePaths.isEmpty) {
        throw Exception('Select at least 1 file to merge');
      }

      final pdf = pw.Document();

      for (final filePath in filePaths) {
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('File not found: $filePath');
        }

        final extension = p.extension(filePath).toLowerCase();

        if (extension == '.pdf') {
          // Add PDF pages as images
          await _addPdfPagesAsImages(pdf, filePath);
        } else if (['.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp'].contains(extension)) {
          // Add image as a PDF page
          await _addImageAsPage(pdf, filePath);
        } else {
          throw Exception('Unsupported file type: $extension');
        }
      }

      // Save the merged PDF
      final tempDir = await getTemporaryDirectory();
      final outputPath = p.join(tempDir.path, outputFileName);

      final mergedBytes = await pdf.save();
      await File(outputPath).writeAsBytes(mergedBytes);

      return outputPath;
    } catch (e) {
      throw Exception('Failed to merge files: $e');
    }
  }



  /// Convert PDF pages to images and add to new PDF
  Future<void> _addPdfPagesAsImages(pw.Document pdf, String pdfPath) async {
    try {
      final pdfBytes = await File(pdfPath).readAsBytes();
      final fileName = p.basename(pdfPath);

      // Use printing package to rasterize PDF pages
      final pages = Printing.raster(pdfBytes, dpi: 200.0);
      int pageIndex = 0;

      await for (final page in pages) {
        try {
          pageIndex++;

          // Convert page to PNG
          final pngBytes = await page.toPng();

          // Add as image page to new PDF
          final pdfImage = pw.MemoryImage(pngBytes);

          // Use original page dimensions
          final pageWidth = page.width.toDouble();
          final pageHeight = page.height.toDouble();

          // Convert pixels to PDF points
          final pdfPageWidth = pageWidth * (72.0 / 200.0); // Convert from 200 DPI to 72 DPI
          final pdfPageHeight = pageHeight * (72.0 / 200.0);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(pdfPageWidth, pdfPageHeight), // Use PdfPageFormat, not pw.PageFormat
              build: (pw.Context context) {
                return pw.Image(
                  pdfImage,
                  width: pdfPageWidth,
                  height: pdfPageHeight,
                  fit: pw.BoxFit.fill,
                );
              },
            ),
          );

        } catch (e) {
          // If page conversion fails, add placeholder
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Text(
                    'Page $pageIndex\n(Conversion Error)',
                    textAlign: pw.TextAlign.center,
                  ),
                );
              },
            ),
          );
        }
      }

    } catch (e) {
      // If PDF parsing fails, add error page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text(
                'Error processing PDF',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 12),
              ),
            );
          },
        ),
      );
    }
  }


  Future<void> _addImageAsPage(pw.Document pdf, String imagePath) async {
    try {
      final file = File(imagePath);
      final imageBytes = await file.readAsBytes();

      // Decode image to get dimensions
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image: $imagePath');
      }

      // Convert to PDF image format
      final pdfImage = pw.MemoryImage(imageBytes);

      // Use image's original dimensions
      final imageWidth = image.width.toDouble();
      final imageHeight = image.height.toDouble();

      // Convert pixels to PDF points (72 DPI)
      final pageWidth = imageWidth * (72.0 / 96.0); // Assuming 96 DPI for conversion
      final pageHeight = imageHeight * (72.0 / 96.0);

      // A4 dimensions
      final a4Width = PdfPageFormat.a4.width;
      final a4Height = PdfPageFormat.a4.height;

      // Check image size relative to A4
      final isSmallerThanA4 = pageWidth < a4Width && pageHeight < a4Height;
      final isLargerThanA4 = pageWidth > a4Width || pageHeight > a4Height;

      if (isSmallerThanA4 || isLargerThanA4) {
        // For both smaller and larger images, use A4 with proper scaling

        // Calculate scaling to fit within A4 while maintaining aspect ratio
        double scaleWidth = a4Width / pageWidth;
        double scaleHeight = a4Height / pageHeight;
        double scale = scaleWidth < scaleHeight ? scaleWidth : scaleHeight;

        // Apply scaling (but don't upscale small images too much)
        if (isSmallerThanA4) {
          // For small images, use 90% of available space (with some margin)
          scale = (scale > 1) ? 0.9 : scale * 0.9;
        } else {
          // For large images, scale down to fit
          scale = scale * 0.95; // 95% to leave small margin
        }

        final scaledWidth = pageWidth * scale;
        final scaledHeight = pageHeight * scale;

        // Use A4 size with centered scaled image on white background
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // White A4 background
                  pw.Container(
                    width: a4Width,
                    height: a4Height,
                    color: PdfColors.white,
                  ),
                  // Centered scaled image
                  pw.Center(
                    child: pw.Container(
                      width: scaledWidth,
                      height: scaledHeight,
                      child: pw.Image(
                        pdfImage,
                        width: scaledWidth,
                        height: scaledHeight,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      } else {
        // Image is approximately A4 size or very close
        // Use original image size (no background)
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(pageWidth, pageHeight),
            build: (pw.Context context) {
              return pw.Image(
                pdfImage,
                width: pageWidth,
                height: pageHeight,
                fit: pw.BoxFit.fill,
              );
            },
          ),
        );
      }
    } catch (e) {
      // Add error page if image loading fails
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text(
                'Error loading image',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 12),
              ),
            );
          },
        ),
      );
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

  /// Get file info
  Future<Map<String, dynamic>> getFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      final extension = p.extension(filePath).toLowerCase();
      final fileName = p.basename(filePath);

      Map<String, dynamic> info = {
        'path': filePath,
        'name': fileName,
        'size': stat.size,
        'formattedSize': _formatFileSize(stat.size),
        'extension': extension,
        'type': _getFileType(extension),
        'modified': stat.modified,
        'formattedDate': _formatDate(stat.modified),
        'exists': true,
      };

      // Add page count for PDFs
      if (extension == '.pdf') {
        try {
          final pageCount = await getPdfPageCount(filePath);
          info['pageCount'] = pageCount;
        } catch (e) {
          info['pageCount'] = 0;
        }
      }

      return info;
    } catch (e) {
      return {
        'path': filePath,
        'name': p.basename(filePath),
        'size': 0,
        'formattedSize': '0 B',
        'extension': '',
        'type': 'unknown',
        'modified': null,
        'formattedDate': 'Unknown',
        'exists': false,
      };
    }
  }

  String _getFileType(String extension) => FileUtils.getFileType(extension);

  String _formatFileSize(int bytes) => FileUtils.formatFileSize(bytes);
  String _formatDate(DateTime date) => FileUtils.formatDate(date);

  /// Save merged file to app directory using FileService
  Future<File> saveToAppDirectory(
      String sourcePath, {
        String? customName,
      }) async {
    final file = File(sourcePath);
    final fileName = customName ?? p.basename(sourcePath);
    final appDir = await getApplicationDocumentsDirectory();
    final pdfLabDir = Directory(p.join(appDir.path, 'pdf_lab_pro'));

    if (!await pdfLabDir.exists()) {
      await pdfLabDir.create(recursive: true);
    }

    final uniqueName = _getUniqueFileName(pdfLabDir, fileName);
    final destinationPath = p.join(pdfLabDir.path, uniqueName);

    await file.copy(destinationPath);
    return File(destinationPath);
  }

  String _getUniqueFileName(Directory dir, String fileName) =>
      FileUtils.getUniqueFileName(dir.path, fileName);
}