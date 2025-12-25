import 'dart:io';
import 'dart:math';

class FileUtils {
  /// Format file size to human readable string
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  /// Format date to relative time or absolute date
  static String formatDate(DateTime date, {bool relative = true}) {
    if (!relative) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    final diff = DateTime.now().difference(date);
    final now = DateTime.now();

    if (date.year != now.year) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } else if (diff.inDays > 7) {
      return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  /// Get file type from extension
  static String getFileType(String extension) {
    final ext = extension.toLowerCase();
    if (ext == '.pdf') return 'PDF';
    if (['.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp'].contains(ext)) {
      return 'Image';
    }
    if (['.doc', '.docx'].contains(ext)) return 'Word';
    if (['.xls', '.xlsx'].contains(ext)) return 'Excel';
    if (['.ppt', '.pptx'].contains(ext)) return 'PowerPoint';
    return 'File';
  }

  /// Generate unique filename in directory
  static String getUniqueFileName(String dirPath, String fileName) {
    final path = fileName;
    var name = path.substring(0, path.lastIndexOf('.'));
    var ext = path.substring(path.lastIndexOf('.'));
    var uniqueName = fileName;
    var counter = 1;

    while (File('$dirPath/$uniqueName').existsSync()) {
      uniqueName = '$name ($counter)$ext';
      counter++;
    }
    return uniqueName;
  }

  /// Estimate PDF pages based on file size
  static int estimatePdfPages(int fileSize) {
    // Rough estimate: ~50KB per page for average PDF
    final pages = (fileSize / (50 * 1024)).ceil();
    return pages.clamp(1, 1000); // Cap at 1000 pages
  }
}