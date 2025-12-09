import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdfrx_engine/pdfrx_engine.dart';

import 'file_service.dart';
import 'package:pdf_lab_pro/utils/constants.dart';

class PdfMergeService {
  PdfMergeService(this._fileService);

  final FileService _fileService;

  // A4 size in PDF points (72 dpi): 595 x 842
  // From pdfrx_engine docs.
  static const double _a4Width = 595.0;
  static const double _a4Height = 842.0;

  static bool _engineInitialized = false;

  static Future<void> _ensureEngineInitialized() async {
    if (!_engineInitialized) {
      await pdfrxInitialize(); // safe to call once
      _engineInitialized = true;
    }
  }

  /// Merge selected files (PDF + images) into one PDF and return bytes.
  ///
  /// [filePaths] can contain:
  ///  - PDF files
  ///  - Image files (jpg, jpeg, png, etc. from AppConstants.imageExtensions)
  Future<Uint8List> mergeFiles({
    required List<String> filePaths,
  }) async {
    if (filePaths.isEmpty) {
      throw ArgumentError('No files selected for merge');
    }

    await _ensureEngineInitialized();

    final outputDoc =
    await PdfDocument.createNew(sourceName: 'merged.pdf');

    final openedDocs = <PdfDocument>[];
    final allPages = <PdfPage>[];

    try {
      for (final filePath in filePaths) {
        final ext = _fileService.getFileExtension(filePath);

        if (ext == '.pdf') {
          // Open existing PDF and collect its pages.
          final srcDoc = await PdfDocument.openFile(filePath);
          if (srcDoc.pages.isNotEmpty) {
            allPages.addAll(srcDoc.pages);
            openedDocs.add(srcDoc);
          } else {
            srcDoc.dispose();
          }
        } else if (AppConstants.imageExtensions.contains(ext)) {
          // Convert image to a single-page A4 PDF using pdfrx_engine.
          final imgDoc = await _createPdfFromImage(filePath);
          if (imgDoc.pages.isNotEmpty) {
            allPages.addAll(imgDoc.pages);
            openedDocs.add(imgDoc);
          } else {
            imgDoc.dispose();
          }
        } else {
          // Unsupported extension – just skip.
          continue;
        }
      }

      if (allPages.isEmpty) {
        throw StateError('No valid pages found to merge');
      }

      // Combine all pages into the new document.
      // This uses pdfrx_engine's page manipulation API.
      outputDoc.pages = allPages;

      final data = await outputDoc.encodePdf();
      return Uint8List.fromList(data);
    } finally {
      // Important: dispose all source documents and output document.
      for (final doc in openedDocs) {
        doc.dispose();
      }
      outputDoc.dispose();
    }
  }

  /// Turn a single image file into a 1-page A4 PDF using pdfrx_engine.
  Future<PdfDocument> _createPdfFromImage(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final ext = _fileService.getFileExtension(filePath);

    Uint8List jpegBytes;

    if (ext == '.jpg' || ext == '.jpeg') {
      // Already JPEG: use as is.
      jpegBytes = bytes;
    } else {
      // Convert PNG / others to JPEG using `image` package.
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw StateError('Unsupported image format: $filePath');
      }
      jpegBytes = Uint8List.fromList(
        img.encodeJpg(decoded, quality: 90),
      );
    }

    // Create a 1-page A4 PDF from JPEG data.
    final imgPdf = await PdfDocument.createFromJpegData(
      jpegBytes,
      width: _a4Width,
      height: _a4Height,
      sourceName: p.basename(filePath),
    );

    return imgPdf;
  }

  /// Save merged bytes into your app's internal "pdf_lab_pro" directory.
  Future<File> saveMergedToAppDirectory(
      Uint8List mergedBytes, {
        String? fileName,
      }) async {
    final dir = await _fileService.getAppDirectory();
    final safeName =
        fileName ?? 'merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(p.join(dir.path, safeName));

    await file.writeAsBytes(mergedBytes, flush: true);
    return file;
  }

  /// Optionally: export to Downloads / public folder.
  /// You can keep or replace your existing permission + export logic here.
  Future<File> saveMergedToCustomPath(
      Uint8List mergedBytes,
      String targetPath,
      ) async {
    final file = File(targetPath);
    await file.writeAsBytes(mergedBytes, flush: true);
    return file;
  }
}
