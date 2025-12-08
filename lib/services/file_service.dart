import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_lab_pro/utils/constants.dart';
import 'package:mime/mime.dart';

class FileService {
  Future<Directory> getAppDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final pdfLabDir = Directory(path.join(appDir.path, AppConstants.appDirectory));
    if (!await pdfLabDir.exists()) {
      await pdfLabDir.create(recursive: true);
    }
    return pdfLabDir;
  }

  Future<Directory> getTempDirectory() async {
    final appDir = await getAppDirectory();
    final tempDir = Directory(path.join(appDir.path, AppConstants.tempDirectory));
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir;
  }

  Future<File> copyToAppDirectory(String sourcePath) async {
    final sourceFile = File(sourcePath);
    final fileName = path.basename(sourcePath);
    final appDir = await getAppDirectory();

    final uniqueFileName = _getUniqueFileName(appDir, fileName);
    final destinationPath = path.join(appDir.path, uniqueFileName);

    await sourceFile.copy(destinationPath);
    return File(destinationPath);
  }

  Future<List<Map<String, dynamic>>> listPDFFiles() async {
    final appDir = await getAppDirectory();
    final files = <Map<String, dynamic>>[];

    try {
      await for (var entity in appDir.list()) {
        if (entity is File) {
          final filePath = entity.path;
          final mimeType = lookupMimeType(filePath);

          if (mimeType == 'application/pdf') {
            final stat = await entity.stat();
            files.add({
              'path': filePath,
              'name': path.basename(filePath),
              'size': _formatFileSize(stat.size),
              'date': _formatDate(stat.modified),
              'modified': stat.modified,
              'icon': Icons.picture_as_pdf,
            });
          }
        }
      }

      files.sort((a, b) => b['modified'].compareTo(a['modified']));
      return files;
    } catch (_) {
      return [];
    }
  }

  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearTempDirectory() async {
    final tempDir = await getTempDirectory();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
      await tempDir.create(recursive: true);
    }
  }

  Future<void> clearAppDirectory() async {
    final appDir = await getAppDirectory();
    if (await appDir.exists()) {
      await appDir.delete(recursive: true);
      await appDir.create(recursive: true);
    }
  }

  // Helpers
  String _getUniqueFileName(Directory dir, String fileName) {
    var name = path.basenameWithoutExtension(fileName);
    var ext = path.extension(fileName);
    var uniqueName = fileName;
    var counter = 1;

    while (File(path.join(dir.path, uniqueName)).existsSync()) {
      uniqueName = '$name ($counter)$ext';
      counter++;
    }
    return uniqueName;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inDays > 365) {
      final y = (diff.inDays / 365).floor();
      return '$y year${y > 1 ? 's' : ''} ago';
    } else if (diff.inDays > 30) {
      final m = (diff.inDays / 30).floor();
      return '$m month${m > 1 ? 's' : ''} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  bool isPDF(String filePath) => lookupMimeType(filePath) == 'application/pdf';

  String getFileExtension(String filePath) => path.extension(filePath).toLowerCase();
}
