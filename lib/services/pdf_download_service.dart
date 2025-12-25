import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class PdfDownloadService {
  /// Opens Android "Save As" dialog
  Future<bool> saveWithSystemPicker({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName: fileName,
      allowedExtensions: ['pdf'],
      type: FileType.custom,
      bytes: bytes, // IMPORTANT
    );

    return path != null;
  }
}
