import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_lab_pro/providers/image_to_pdf_provider.dart';
import 'package:pdf_lab_pro/utils/constants.dart';

class ImageToPdfScreen extends ConsumerStatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  ConsumerState<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends ConsumerState<ImageToPdfScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageToPdfProvider);
    final notifier = ref.read(imageToPdfProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image to PDF', style: TextStyle(fontSize: 16)),
        actions: [
          if (state.selectedImages.isNotEmpty || state.convertedFilePath != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: notifier.reset,
              tooltip: 'Clear All',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Info',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Add Images Button
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Convert Images to PDF',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Supported: JPG, PNG, GIF, BMP, WebP',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _pickImages(notifier),
                                    icon: const Icon(Icons.add_photo_alternate),
                                    label: const Text('Add Images'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 50),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Selected Images List
                    if (state.selectedImages.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Selected Images (${state.selectedImages.length})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (state.selectedImages.length >= 2)
                                    Text(
                                      'Drag to reorder',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: constraints.maxHeight * 0.4,
                                  minHeight: 100,
                                ),
                                child: ReorderableListView.builder(
                                  shrinkWrap: true,
                                  itemCount: state.selectedImages.length,
                                  onReorder: (oldIndex, newIndex) {
                                    notifier.reorderImages(oldIndex, newIndex);
                                  },
                                  itemBuilder: (context, index) {
                                    final imagePath = state.selectedImages[index];
                                    final imageInfo = state.imageInfo.length > index
                                        ? state.imageInfo[index]
                                        : null;

                                    final fileName = imageInfo?['name'] ?? 'Image ${index + 1}';
                                    final fileSize = imageInfo?['formattedSize'] ?? '...';
                                    final fileType = imageInfo?['type'] ?? 'Image';

                                    return _ImageListItem(
                                      key: ValueKey(imagePath),
                                      imagePath: imagePath,
                                      fileName: fileName,
                                      fileSize: fileSize,
                                      fileType: fileType,
                                      index: index + 1,
                                      onRemove: () => notifier.removeImage(imagePath),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Empty state
                      Container(
                        height: constraints.maxHeight * 0.4,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No images selected',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap "Add Images" to select photos',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Compression Settings (ADDED HERE)
                    if (state.selectedImages.isNotEmpty) ...[
                      _buildCompressionSettings(state, notifier),
                      const SizedBox(height: 16),
                    ],

                    // Status Messages
                    if (state.error != null) ...[
                      _StatusMessage(
                        message: state.error!,
                        isError: true,
                        onClose: () => notifier.clearError(),
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (state.success != null) ...[
                      _StatusMessage(
                        message: state.success!,
                        isError: false,
                        onClose: () => notifier.clearSuccess(),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Conversion Progress
                    if (state.isConverting) ...[
                      _ConversionProgress(progress: state.progress),
                      const SizedBox(height: 16),
                    ],

                    // Converted PDF Actions
                    if (state.convertedFilePath != null) ...[
                      _ConvertedPdfSection(
                        filePath: state.convertedFilePath!,
                        onOpen: () => _openFile(state.convertedFilePath!),
                        onShare: () => _shareFile(state.convertedFilePath!),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Convert Button
                    if (state.selectedImages.isNotEmpty)
                      _BottomConvertButton(
                        isLoading: state.isConverting,
                        imageCount: state.selectedImages.length,
                        onConvert: () => notifier.convertToPdf(),
                      ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============== COMPRESSION SETTINGS WIDGET ==============
  Widget _buildCompressionSettings(ImageToPdfState state, ImageToPdfProvider notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'PDF Compression',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reduce file size by lowering image quality',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Toggle Switch
            SwitchListTile(
              title: const Text('Reduce File Size'),
              subtitle: Text(
                state.reduceFileSize
                    ? 'Images will be compressed to reduce PDF size'
                    : 'Keep original image quality',
              ),
              value: state.reduceFileSize,
              onChanged: (value) => notifier.setReduceFileSize(value),
              secondary: Icon(
                state.reduceFileSize ? Icons.compress : Icons.high_quality,
                color: state.reduceFileSize ? Colors.blue : Colors.grey,
              ),
            ),

            // Quality Slider (only show when compression is enabled)
            if (state.reduceFileSize) ...[
              const SizedBox(height: 16),
              ListTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Image Quality: ${state.imageQuality}%'),
                    const SizedBox(height: 8),
                    Slider(
                      value: state.imageQuality.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 9,
                      onChanged: (value) => notifier.setImageQuality(value.toInt()),
                      label: '${state.imageQuality}%',
                      activeColor: _getQualityColor(state.imageQuality),
                      inactiveColor: Colors.grey.shade300,
                    ),
                  ],
                ),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Smaller PDF',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Better Quality',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Quality indicators
              const SizedBox(height: 8),
              Row(
                children: [
                  _QualityIndicator(
                    label: 'Low',
                    percent: '10-40%',
                    color: Colors.red,
                    isActive: state.imageQuality <= 40,
                  ),
                  _QualityIndicator(
                    label: 'Medium',
                    percent: '40-70%',
                    color: Colors.orange,
                    isActive: state.imageQuality > 40 && state.imageQuality <= 70,
                  ),
                  _QualityIndicator(
                    label: 'High',
                    percent: '70-90%',
                    color: Colors.green,
                    isActive: state.imageQuality > 70 && state.imageQuality <= 90,
                  ),
                  _QualityIndicator(
                    label: 'Best',
                    percent: '90-100%',
                    color: Colors.blue,
                    isActive: state.imageQuality > 90,
                  ),
                ],
              ),

              // Size estimate
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getSizeEstimateText(state, ref),
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getSizeEstimateText(ImageToPdfState state, WidgetRef ref) {
    if (!state.reduceFileSize) {
      return 'Original image quality will be preserved';
    }

    final estimate = ref.read(imageToPdfProvider.notifier).getSizeEstimate();
    return estimate['estimate'];
  }
  // Helper method for quality color
  Color _getQualityColor(int quality) {
    if (quality <= 40) return Colors.red;
    if (quality <= 70) return Colors.orange;
    if (quality <= 90) return Colors.green;
    return Colors.blue;
  }

// In the UI file, update the _getSizeEstimate() method:

  Future<Map<String, dynamic>> _getSizeEstimate() async {
    final state = ref.read(imageToPdfProvider);

    if (!state.reduceFileSize || state.selectedImages.isEmpty) {
      return {'estimate': 'Original image quality'};
    }

    // Calculate total size of selected images
    int totalSize = 0;
    for (final path in state.selectedImages) {
      final file = File(path);
      if (await file.exists()) {
        totalSize += await file.length();
      }
    }

    if (totalSize == 0) return {'estimate': 'Unable to calculate size'};

    final quality = state.imageQuality;
    final reduction = _getEstimatedReduction(quality);
    final estimatedSize = (totalSize * (100 - reduction) / 100).toInt();

    return {
      'estimate': 'PDF size reduced by ~$reduction% '
          '(${_formatSize(estimatedSize)} estimated)',
      'originalSize': totalSize,
      'estimatedSize': estimatedSize,
      'reduction': reduction,
    };
  }

  int _getEstimatedReduction(int quality) {
    if (quality <= 40) return 75;
    if (quality <= 70) return 50;
    if (quality <= 90) return 30;
    return 10;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ============== REST OF THE SCREEN METHODS ==============
  Future<void> _pickImages(ImageToPdfProvider notifier) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );

      if (result != null && result.files.isNotEmpty) {
        final imagePaths = result.files
            .where((file) => file.path != null)
            .map((file) => file.path!)
            .toList();

        await notifier.selectImages(imagePaths);
      }
    } catch (e) {
      _showError('Error selecting images: $e');
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      context.push(
        '${RoutePaths.viewPdf}?path=${Uri.encodeComponent(filePath)}',
      );
    } catch (e) {
      _showError('Cannot open file: $e');
    }
  }

  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      _showError('Cannot share file: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Image to PDF Guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to use:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Tap "Add Images" to select photos'),
              Text('2. Drag images to reorder them'),
              Text('3. Adjust compression settings if needed'),
              Text('4. Tap "Convert to PDF" button'),
              Text('5. Open or share the PDF'),
              SizedBox(height: 16),
              Text(
                'Compression Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('- Use 85-100% for photo albums'),
              Text('- Use 70-85% for documents with images'),
              Text('- Use 40-70% for maximum file reduction'),
              Text('- Each image becomes one PDF page'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// ============== WIDGET CLASSES ==============

class _ImageListItem extends StatelessWidget {
  final String imagePath;
  final String fileName;
  final String fileSize;
  final String fileType;
  final int index;
  final VoidCallback onRemove;

  const _ImageListItem({
    required Key key,
    required this.imagePath,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.index,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey),
            const SizedBox(width: 8),
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    image: DecorationImage(
                      image: FileImage(File(imagePath)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        title: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '$fileType • $fileSize',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: onRemove,
          tooltip: 'Remove',
        ),
      ),
    );
  }
}

class _QualityIndicator extends StatelessWidget {
  final String label;
  final String percent;
  final Color color;
  final bool isActive;

  const _QualityIndicator({
    required this.label,
    required this.percent,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? color : Colors.grey.shade600,
            ),
          ),
          Text(
            percent,
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback onClose;

  const _StatusMessage({
    required this.message,
    required this.isError,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red[200]! : Colors.green[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error : Icons.check_circle,
            color: isError ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.red : Colors.green,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _ConversionProgress extends StatelessWidget {
  final int progress;

  const _ConversionProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Converting Images...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '$progress% Complete',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConvertedPdfSection extends StatelessWidget {
  final String filePath;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  const _ConvertedPdfSection({
    required this.filePath,
    required this.onOpen,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    final fileSize = (file.lengthSync() / 1024).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '✅ Conversion Complete!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('converted.pdf'),
              subtitle: Text(
                'Size: ${fileSize} KB',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomConvertButton extends StatelessWidget {
  final bool isLoading;
  final int imageCount;
  final VoidCallback onConvert;

  const _BottomConvertButton({
    required this.isLoading,
    required this.imageCount,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ElevatedButton(
        onPressed: isLoading ? null : onConvert,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColorDark,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 24),
            const SizedBox(width: 12),
            Text(
              'Convert $imageCount Image${imageCount > 1 ? 's' : ''} to PDF',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}