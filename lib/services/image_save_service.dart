import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class ImageSaveService {
  Future<int> saveMultipleImages({
    required List<String> imagePaths,
    required String baseName,
  }) async {
    int savedCount = 0;

    try {
      // Request necessary permissions for Android 13+
      if (Platform.isAndroid) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          // If permission denied, try with storage permission for older Android
          if (await Permission.storage.isDenied) {
            final storageStatus = await Permission.storage.request();
            if (!storageStatus.isGranted) {
              throw Exception('Storage permission denied');
            }
          }
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          throw Exception('Photos permission denied');
        }
      }

      // Save each image
      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        final file = File(imagePath);

        if (await file.exists()) {
          // Create unique filename
          final fileName = '${baseName}_page_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.png';

          // Save to gallery
          final result = await GallerySaver.saveImage(
            imagePath,
            albumName: 'PDF Lab Pro',
            toDcim: true,
          );

          if (result == true || result == 'true') {
            savedCount++;
            print('✅ Saved image ${i + 1}: $imagePath');
          } else {
            print('❌ Failed to save image ${i + 1}: $imagePath');
            print('GallerySaver result: $result');

            // Try alternative method for saving
            try {
              await _saveToAppDirectory(file, fileName);
              savedCount++;
            } catch (e) {
              print('Alternative save also failed: $e');
            }
          }
        } else {
          print('⚠️ Image file not found: $imagePath');
        }
      }

      return savedCount;

    } catch (e) {
      print('Error saving images: $e');
      rethrow;
    }
  }

  Future<bool> saveImageToGallery(String imagePath, String fileName) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.photos.status;
        if (!status.isGranted) {
          final result = await Permission.photos.request();
          if (!result.isGranted) {
            // Try storage permission for older Android
            if (await Permission.storage.isDenied) {
              final storageResult = await Permission.storage.request();
              if (!storageResult.isGranted) {
                return false;
              }
            }
          }
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.status;
        if (!status.isGranted) {
          final result = await Permission.photos.request();
          if (!result.isGranted) {
            return false;
          }
        }
      }

      if (!await File(imagePath).exists()) {
        return false;
      }

      final result = await GallerySaver.saveImage(
        imagePath,
        albumName: 'PDF Lab Pro',
        toDcim: true,
      );

      // Handle both bool and string returns
      return result == true || result == 'true';

    } catch (e) {
      print('Error saving single image: $e');
      return false;
    }
  }

  // Alternative method: Save to app's documents directory
  Future<void> _saveToAppDirectory(File sourceFile, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final pdfLabDir = Directory('${appDir.path}/PDF Lab Pro');

      if (!await pdfLabDir.exists()) {
        await pdfLabDir.create(recursive: true);
      }

      final destinationPath = '${pdfLabDir.path}/$fileName';
      await sourceFile.copy(destinationPath);
      print('✅ Image saved to app directory: $destinationPath');
    } catch (e) {
      print('Error saving to app directory: $e');
      rethrow;
    }
  }

  Future<void> shareMultipleImages(List<String> imagePaths) async {
    try {
      if (imagePaths.isEmpty) {
        throw Exception('No images to share');
      }

      // Filter out non-existent files
      final existingFiles = <String>[];
      for (final path in imagePaths) {
        if (await File(path).exists()) {
          existingFiles.add(path);
        }
      }

      if (existingFiles.isEmpty) {
        throw Exception('No valid image files found');
      }

      // Convert to XFiles for sharing
      final xFiles = existingFiles.map((path) => XFile(path)).toList();

      await Share.shareXFiles(
        xFiles,
        text: 'PDF converted images from PDF Lab Pro',
        subject: 'PDF Images',
      );

    } catch (e) {
      print('Error sharing images: $e');
      rethrow;
    }
  }

  Future<void> clearTempFiles(List<String> filePaths) async {
    try {
      for (final filePath in filePaths) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('Error deleting file $filePath: $e');
        }
      }
    } catch (e) {
      print('Error clearing temp files: $e');
    }
  }
}