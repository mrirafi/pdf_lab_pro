import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf_lab_pro/utils/file_utils.dart';

/// Split mode options
enum SplitMode {
  pageRange('Page Ranges', Icons.format_list_numbered),
  everyNPages('Every N Pages', Icons.call_split),
  singlePages('Single Pages', Icons.view_array),
  ;

  final String label;
  final IconData icon;

  const SplitMode(this.label, this.icon);
}

/// Range input parser for page ranges like "1-5, 8, 10-15"
class PageRangeParser {
  static List<List<int>> parseRanges(String input, int totalPages) {
    if (input.isEmpty) return [];

    final ranges = <List<int>>[];
    final parts = input.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);

    for (final part in parts) {
      if (part.contains('-')) {
        // Range like "1-5"
        final rangeParts = part.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0]) ?? 1;
          final end = int.tryParse(rangeParts[1]) ?? totalPages;
          if (start >= 1 && end <= totalPages && start <= end) {
            ranges.add([start, end]);
          }
        }
      } else {
        // Single page like "8"
        final page = int.tryParse(part) ?? 1;
        if (page >= 1 && page <= totalPages) {
          ranges.add([page, page]);
        }
      }
    }

    return ranges;
  }

  static bool isValidRange(String input, int totalPages) {
    try {
      final ranges = parseRanges(input, totalPages);
      return ranges.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

class PdfSplitService {
  /// Split PDF by page ranges
  Future<List<String>> splitByRanges({
    required String pdfPath,
    required List<List<int>> ranges,
    required String baseName,
  }) async {
    try {
      final pdfBytes = await File(pdfPath).readAsBytes();
      final tempDir = await getTemporaryDirectory();
      final outputFiles = <String>[];

      for (int i = 0; i < ranges.length; i++) {
        final range = ranges[i];
        final startPage = range[0];
        final endPage = range[1];

        final splitPdf = await _extractPageRange(
          pdfBytes: pdfBytes,
          startPage: startPage,
          endPage: endPage,
        );

        final fileName = '${baseName}_part_${i + 1}_pages_${startPage}_to_${endPage}.pdf';
        final outputPath = p.join(tempDir.path, fileName);
        await File(outputPath).writeAsBytes(splitPdf);
        outputFiles.add(outputPath);
      }

      return outputFiles;
    } catch (e) {
      throw Exception('Failed to split by ranges: $e');
    }
  }

  /// Split PDF every N pages
  Future<List<String>> splitEveryNPages({
    required String pdfPath,
    required int n,
    required String baseName,
  }) async {
    try {
      final pdfBytes = await File(pdfPath).readAsBytes();
      final totalPages = await _getPageCount(pdfBytes);
      final tempDir = await getTemporaryDirectory();
      final outputFiles = <String>[];

      int partNumber = 1;
      for (int start = 1; start <= totalPages; start += n) {
        final end = min(start + n - 1, totalPages);

        final splitPdf = await _extractPageRange(
          pdfBytes: pdfBytes,
          startPage: start,
          endPage: end,
        );

        final fileName = '${baseName}_part_${partNumber}_pages_${start}_to_${end}.pdf';
        final outputPath = p.join(tempDir.path, fileName);
        await File(outputPath).writeAsBytes(splitPdf);
        outputFiles.add(outputPath);
        partNumber++;
      }

      return outputFiles;
    } catch (e) {
      throw Exception('Failed to split every $n pages: $e');
    }
  }

  /// Split into single pages
  Future<List<String>> splitIntoSinglePages({
    required String pdfPath,
    required String baseName,
  }) async {
    try {
      final pdfBytes = await File(pdfPath).readAsBytes();
      final totalPages = await _getPageCount(pdfBytes);
      final tempDir = await getTemporaryDirectory();
      final outputFiles = <String>[];

      for (int page = 1; page <= totalPages; page++) {
        final splitPdf = await _extractPageRange(
          pdfBytes: pdfBytes,
          startPage: page,
          endPage: page,
        );

        final fileName = '${baseName}_page_${page}.pdf';
        final outputPath = p.join(tempDir.path, fileName);
        await File(outputPath).writeAsBytes(splitPdf);
        outputFiles.add(outputPath);
      }

      return outputFiles;
    } catch (e) {
      throw Exception('Failed to split into single pages: $e');
    }
  }

  /// Extract page range from PDF bytes
  Future<Uint8List> _extractPageRange({
    required Uint8List pdfBytes,
    required int startPage,
    required int endPage,
  }) async {
    final pdf = pw.Document();
    final pages = Printing.raster(pdfBytes, dpi: 150.0);
    int currentPage = 0;

    await for (final page in pages) {
      currentPage++;
      if (currentPage >= startPage && currentPage <= endPage) {
        try {
          // Get original page dimensions in PDF points (72 DPI)
          final pageWidth = page.width.toDouble() * (72.0 / 150.0);
          final pageHeight = page.height.toDouble() * (72.0 / 150.0);

          // Convert page to image
          final pageImage = await page.toPng();
          final pdfImage = pw.MemoryImage(pageImage);

          // Use original page dimensions, not A4
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(pageWidth, pageHeight),
              build: (pw.Context context) {
                return pw.Image(
                  pdfImage,
                  width: pageWidth,
                  height: pageHeight,
                  fit: pw.BoxFit.fill, // Fill entire page
                );
              },
            ),
          );
        } catch (e) {
          // Error placeholder with original size
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Text('Page $currentPage\n(Error extracting)'),
                );
              },
            ),
          );
        }
      }

      if (currentPage > endPage) break;
    }

    return await pdf.save();
  }

  /// Get total page count
  Future<int> _getPageCount(Uint8List pdfBytes) async {
    try {
      final pages = Printing.raster(pdfBytes, dpi: 72.0);
      int pageCount = 0;
      await for (final _ in pages) {
        pageCount++;
      }
      return pageCount;
    } catch (e) {
      // Estimate based on file size
      final estimatedPages = (pdfBytes.length / (100 * 1024)).ceil();
      return estimatedPages.clamp(1, 1000);
    }
  }

  /// Get PDF info
  Future<Map<String, dynamic>> getPdfInfo(String pdfPath) async {
    try {
      final file = File(pdfPath);
      final stat = await file.stat();
      final pdfBytes = await file.readAsBytes();
      final pageCount = await _getPageCount(pdfBytes);

      return {
        'path': pdfPath,
        'name': p.basename(pdfPath),
        'size': stat.size,
        'formattedSize': FileUtils.formatFileSize(stat.size),
        'pageCount': pageCount,
        'modified': stat.modified,
      };
    } catch (e) {
      throw Exception('Failed to get PDF info: $e');
    }
  }
}