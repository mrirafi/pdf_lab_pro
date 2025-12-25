import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_lab_pro/utils/constants.dart';
import 'package:pdf_lab_pro/utils/file_utils.dart';

class FileService {
  // Get app's private documents directory
  Future<Directory> _getAppDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final pdfLabDir = Directory(p.join(appDir.path, AppConstants.appDirectory));

    if (!await pdfLabDir.exists()) {
      await pdfLabDir.create(recursive: true);
    }

    return pdfLabDir;
  }

  // Get temporary directory
  Future<Directory> _getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final pdfLabTempDir = Directory(p.join(tempDir.path, AppConstants.tempDirectory));

    if (!await pdfLabTempDir.exists()) {
      await pdfLabTempDir.create(recursive: true);
    }

    return pdfLabTempDir;
  }

  /// List all PDF files in app directory
  Future<List<Map<String, dynamic>>> listPDFFiles() async {
    try {
      final appDir = await _getAppDirectory();
      final files = await appDir.list().toList();

      final pdfFiles = <Map<String, dynamic>>[];

      for (final file in files) {
        if (file is File) {
          final path = file.path;
          final extension = p.extension(path).toLowerCase();

          if (AppConstants.supportedExtensions.contains(extension) ||
              AppConstants.imageExtensions.contains(extension)) {
            try {
              final stat = await file.stat();
              final size = FileUtils.formatFileSize(stat.size);
              final date = FileUtils.formatDate(stat.modified);
              final name = p.basename(path);

              pdfFiles.add({
                'path': path,
                'name': name,
                'size': size,
                'formattedSize': size,
                'date': date,
                'modified': stat.modified,
                'extension': extension,
                'type': FileUtils.getFileType(extension),
              });
            } catch (e) {
              print('Error reading file $path: $e');
            }
          }
        }
      }

      // Sort by modification date (newest first)
      pdfFiles.sort((a, b) =>
          (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));

      return pdfFiles;
    } catch (e) {
      print('Error listing PDF files: $e');
      return [];
    }
  }

  /// Copy file to app's private directory
  Future<File> copyToAppDirectory(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist: $sourcePath');
      }

      final appDir = await _getAppDirectory();
      final fileName = p.basename(sourcePath);
      final uniqueName = _getUniqueFileName(appDir, fileName);
      final destinationPath = p.join(appDir.path, uniqueName);

      return await sourceFile.copy(destinationPath);
    } catch (e) {
      throw Exception('Failed to copy file: $e');
    }
  }

  /// Save bytes to app directory
  Future<File> saveToAppDirectory(
      List<int> bytes, {
        required String fileName,
      }) async {
    try {
      final appDir = await _getAppDirectory();
      final uniqueName = _getUniqueFileName(appDir, fileName);
      final filePath = p.join(appDir.path, uniqueName);

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  /// Save to temporary directory (for processing)
  Future<File> saveToTempDirectory(
      List<int> bytes, {
        required String fileName,
      }) async {
    try {
      final tempDir = await _getTempDirectory();
      final uniqueName = _getUniqueFileName(tempDir, fileName);
      final filePath = p.join(tempDir.path, uniqueName);

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      throw Exception('Failed to save to temp: $e');
    }
  }

  /// Delete file from app directory
  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Clear all files from app directory
  Future<void> clearAppDirectory() async {
    try {
      final appDir = await _getAppDirectory();
      if (await appDir.exists()) {
        await appDir.delete(recursive: true);
        await appDir.create(recursive: true);
      }
    } catch (e) {
      throw Exception('Failed to clear app directory: $e');
    }
  }

  /// Clear temporary directory
  Future<void> clearTempDirectory() async {
    try {
      final tempDir = await _getTempDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create(recursive: true);
      }
    } catch (e) {
      throw Exception('Failed to clear temp directory: $e');
    }
  }

  /// Get file information
  Future<Map<String, dynamic>> getFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {
          'exists': false,
          'name': p.basename(filePath),
          'error': 'File not found',
        };
      }

      final stat = await file.stat();
      final extension = p.extension(filePath).toLowerCase();

      return {
        'exists': true,
        'path': filePath,
        'name': p.basename(filePath),
        'size': stat.size,
        'formattedSize': FileUtils.formatFileSize(stat.size),
        'modified': stat.modified,
        'formattedDate': FileUtils.formatDate(stat.modified),
        'extension': extension,
        'type': FileUtils.getFileType(extension),
        'isDirectory': false,
      };
    } catch (e) {
      return {
        'exists': false,
        'name': p.basename(filePath),
        'error': e.toString(),
      };
    }
  }

  /// Check file size (returns in bytes)
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Check if file exists
  Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final appDir = await _getAppDirectory();
      final tempDir = await _getTempDirectory();

      int appDirSize = await _getDirectorySize(appDir);
      int tempDirSize = await _getDirectorySize(tempDir);
      int totalSize = appDirSize + tempDirSize;

      return {
        'appDirectorySize': appDirSize,
        'tempDirectorySize': tempDirSize,
        'totalSize': totalSize,
        'appDirectorySizeFormatted': FileUtils.formatFileSize(appDirSize),
        'tempDirectorySizeFormatted': FileUtils.formatFileSize(tempDirSize),
        'totalSizeFormatted': FileUtils.formatFileSize(totalSize),
        'appDirectoryPath': appDir.path,
        'tempDirectoryPath': tempDir.path,
      };
    } catch (e) {
      return {
        'appDirectorySize': 0,
        'tempDirectorySize': 0,
        'totalSize': 0,
        'appDirectorySizeFormatted': '0 B',
        'tempDirectorySizeFormatted': '0 B',
        'totalSizeFormatted': '0 B',
        'error': e.toString(),
      };
    }
  }

  /// Get unique file name to avoid overwrites
  String _getUniqueFileName(Directory dir, String fileName) {
    final name = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    var uniqueName = fileName;
    int counter = 1;

    while (File(p.join(dir.path, uniqueName)).existsSync()) {
      uniqueName = '$name ($counter)$ext';
      counter++;
    }

    return uniqueName;
  }

  /// Recursively calculate directory size
  Future<int> _getDirectorySize(Directory dir) async {
    try {
      if (!await dir.exists()) return 0;

      int totalSize = 0;
      final files = await dir.list().toList();

      for (final file in files) {
        if (file is File) {
          try {
            totalSize += await file.length();
          } catch (e) {
            print('Error getting file size: $e');
          }
        } else if (file is Directory) {
          totalSize += await _getDirectorySize(file);
        }
      }

      return totalSize;
    } catch (e) {
      print('Error calculating directory size: $e');
      return 0;
    }
  }

  /// Clean up old temporary files (older than 24 hours)
  Future<void> cleanupOldTempFiles() async {
    try {
      final tempDir = await _getTempDirectory();
      final files = await tempDir.list().toList();
      final now = DateTime.now();

      for (final file in files) {
        if (file is File) {
          try {
            final stat = await file.stat();
            final age = now.difference(stat.modified);

            // Delete files older than 24 hours
            if (age.inHours > 24) {
              await file.delete();
            }
          } catch (e) {
            print('Error cleaning up temp file: $e');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up temp files: $e');
    }
  }
}