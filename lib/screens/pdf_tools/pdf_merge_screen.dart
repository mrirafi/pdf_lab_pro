import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_lab_pro/screens/viewer/fast_pdf_viewer.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/pdf_provider.dart';

class PdfMergeScreen extends ConsumerStatefulWidget {
  const PdfMergeScreen({super.key});

  @override
  ConsumerState<PdfMergeScreen> createState() => _PdfMergeScreenState();
}

class _PdfMergeScreenState extends ConsumerState<PdfMergeScreen> {

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfProvider);
    final notifier = ref.read(pdfProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDF & Images', style: TextStyle(fontSize: 16)),
        actions: [
          if (state.selectedFiles.isNotEmpty || state.mergedFilePath != null)
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
                  mainAxisSize: MainAxisSize.min, // Changed to min
                  children: [
                    // Add Files Button
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Add PDFs & Images to Merge',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Supported: PDF, JPG, PNG, BMP, GIF, WebP',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _pickFiles(notifier),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Files'),
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

                    // Selected Files List
                    if (state.selectedFiles.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Selected Files (${state.selectedFiles.length})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (state.selectedFiles.length >= 2)
                                    Text(
                                      'Ready to merge',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Constrained height for the list
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: constraints.maxHeight * 0.5, // Limit height
                                  minHeight: 100,
                                ),
                                child: ReorderableListView.builder(
                                  shrinkWrap: true,
                                  itemCount: state.selectedFiles.length,
                                  onReorder: (oldIndex, newIndex) {
                                    notifier.reorderFiles(oldIndex, newIndex);
                                  },
                                  itemBuilder: (context, index) {
                                    final filePath = state.selectedFiles[index];
                                    final fileInfo = state.selectedFilesInfo.length > index
                                        ? state.selectedFilesInfo[index]
                                        : null;

                                    final fileName = fileInfo?['name'] ??
                                        filePath.split('/').last;
                                    final isPdf = fileName.toLowerCase().endsWith('.pdf');
                                    final fileSize = fileInfo?['formattedSize'] ?? '...';
                                    final fileType = fileInfo?['type'] ?? 'Unknown';

                                    return _FileListItem(
                                      key: ValueKey(filePath),
                                      filePath: filePath,
                                      fileName: fileName,
                                      isPdf: isPdf,
                                      fileSize: fileSize,
                                      fileType: fileType,
                                      pageCount: fileInfo?['pageCount'],
                                      onRemove: () => notifier.deselectFile(filePath),
                                      index: index,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Empty state - use flexible height
                      Container(
                        height: constraints.maxHeight * 0.5,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No files selected',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap "Add Files" to select PDFs or images',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You need at least 2 files to merge',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

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

                    // Merged File Actions
                    if (state.mergedFilePath != null) ...[
                      _MergedFileSection(
                        filePath: state.mergedFilePath!,
                        onOpen: () => _openFile(state.mergedFilePath!),
                        onShare: () => _shareFile(state.mergedFilePath!),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Merge Button at Bottom
                    if (state.selectedFiles.isNotEmpty && state.mergedFilePath == null)
                      _BottomMergeButton(
                        isLoading: state.isLoading,
                        fileCount: state.selectedFiles.length,
                        onMerge: () => notifier.mergeSelectedFiles(),
                      ),

                    // Add some bottom padding for safety
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

  Future<void> _pickFiles(PdfProvider notifier) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'],
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            await notifier.selectFile(file.path!);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting files: $e'),
        ),
      );
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      // Use your existing PDF viewer
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FastPDFViewer(
            filePath: filePath,
          ),
        ),
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
        title: const Text('Merge PDF & Images'),
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
              Text('1. Tap "Add Files" to select PDFs and/or images'),
              Text('2. Long press and drag files to reorder them'),
              Text('3. Files will be merged in the order shown'),
              Text('4. Tap "Merge Files" button at the bottom'),
              Text('5. Open or share the merged PDF'),
              SizedBox(height: 16),
              Text(
                'Note:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('- All images will be converted to PDF pages'),
              Text('- PDF pages are converted to images for merging'),
              Text('- Large files may take longer to process'),
              Text('- Minimum 2 files required to merge'),
              Text('- Drag the ⋮⋮ icon to reorder files'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final Key key;
  final String filePath;
  final String fileName;
  final bool isPdf;
  final String fileSize;
  final String fileType;
  final int? pageCount;
  final VoidCallback onRemove;
  final int index;

  const _FileListItem({
    required this.key,
    required this.filePath,
    required this.fileName,
    required this.isPdf,
    required this.fileSize,
    required this.fileType,
    this.pageCount,
    required this.onRemove,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 70, // Minimum height
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drag_handle, color: Colors.grey),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPdf ? Colors.red[100] : Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf : Icons.image,
                  color: isPdf ? Colors.red : Colors.blue,
                  size: 24,
                ),
              ),
            ],
          ),
          title: Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$fileType • $fileSize',
                style: const TextStyle(fontSize: 12),
              ),
              if (pageCount != null && pageCount! > 0)
                Text(
                  '$pageCount page${pageCount! > 1 ? 's' : ''} • Position: ${index + 1}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onRemove,
            tooltip: 'Remove',
          ),
        ),
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

class _MergedFileSection extends StatelessWidget {
  final String filePath;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  const _MergedFileSection({
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
              '✅ Merge Complete!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('merged.pdf'),
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

class _BottomMergeButton extends StatelessWidget {
  final bool isLoading;
  final int fileCount;
  final VoidCallback onMerge;

  const _BottomMergeButton({
    required this.isLoading,
    required this.fileCount,
    required this.onMerge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ElevatedButton(
        onPressed: fileCount >= 2 && !isLoading ? onMerge : null,
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
            const Icon(Icons.merge, size: 24),
            const SizedBox(width: 12),
            Text(
              fileCount >= 2
                  ? 'Merge $fileCount Files'
                  : 'Need ${2 - fileCount} More File${fileCount == 0 ? 's' : ''}',
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