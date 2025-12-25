import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_lab_pro/screens/viewer/fast_pdf_viewer.dart';
import '../../providers/pdf_reorder_provider.dart';

class ReorderPagesScreen extends ConsumerStatefulWidget {
  const ReorderPagesScreen({super.key});

  @override
  ConsumerState<ReorderPagesScreen> createState() => _ReorderPagesScreenState();
}

class _ReorderPagesScreenState extends ConsumerState<ReorderPagesScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfReorderProvider);
    final notifier = ref.read(pdfReorderProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Pages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (state.pdfPath != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: notifier.reset,
              tooltip: 'Reset',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Info',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File Selection Card
            if (state.pdfPath == null) ...[
              _FileSelectionCard(
                onSelectPdf: () => _selectPdf(notifier),
              ),
              const SizedBox(height: 16),
            ],

            // PDF Info Card
            if (state.pdfPath != null) ...[
              _PdfInfoCard(
                pdfName: state.pdfName ?? 'Unknown',
                pageCount: state.pageCount ?? 0,
                onReset: notifier.reset,
              ),
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

            // Pages Grid
            if (state.pageThumbnails.isNotEmpty) ...[
              Expanded(
                child: _PagesGridView(
                  thumbnails: state.pageThumbnails,
                  currentOrder: state.currentOrder,
                  onReorder: (oldIndex, newIndex) =>
                      notifier.reorderPages(oldIndex, newIndex),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (state.pageThumbnails.isNotEmpty) ...[
              _ActionButtons(
                isLoading: state.isLoading,
                onApply: () => notifier.applyReorder(),
                onResetOrder: () => notifier.resetOrder(),
                hasChanges: _hasOrderChanged(state),
              ),
              const SizedBox(height: 8),
            ],

            // Reordered File Actions
            if (state.reorderedFilePath != null) ...[
              _ReorderedFileSection(
                filePath: state.reorderedFilePath!,
                onOpen: () => _openFile(state.reorderedFilePath!),
                onShare: () => _shareFile(state.reorderedFilePath!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasOrderChanged(ReorderPagesState state) {
    if (state.currentOrder.isEmpty) return false;
    for (int i = 0; i < state.currentOrder.length; i++) {
      if (state.currentOrder[i] != i) return true;
    }
    return false;
  }

  Future<void> _selectPdf(PdfReorderProvider notifier) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await notifier.loadPdf(result.files.single.path!);
      }
    } catch (e) {
      _showError('Error selecting PDF: $e');
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
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
        title: const Text('Reorder PDF Pages'),
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
              Text('1. Select a PDF file'),
              Text('2. Long press and drag pages to reorder'),
              Text('3. Click "Apply Reorder" to save changes'),
              Text('4. Open or share the reordered PDF'),
              SizedBox(height: 16),
              Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('- Drag the drag handle (⋮⋮) to reorder'),
              Text('- Use "Reset Order" to revert changes'),
              Text('- Large PDFs may take time to process'),
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

class _FileSelectionCard extends StatelessWidget {
  final VoidCallback onSelectPdf;

  const _FileSelectionCard({required this.onSelectPdf});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.reorder, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Reorder PDF Pages',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Drag and drop pages to reorder them',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onSelectPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Select PDF File'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfInfoCard extends StatelessWidget {
  final String pdfName;
  final int pageCount;
  final VoidCallback onReset;

  const _PdfInfoCard({
    required this.pdfName,
    required this.pageCount,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.picture_as_pdf, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pdfName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$pageCount page${pageCount != 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onReset,
              tooltip: 'Change PDF',
            ),
          ],
        ),
      ),
    );
  }
}

class _PagesGridView extends StatelessWidget {
  final List<Uint8List> thumbnails;
  final List<int> currentOrder;
  final Function(int, int) onReorder;

  const _PagesGridView({
    required this.thumbnails,
    required this.currentOrder,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Drag to Reorder Pages',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: thumbnails.length,
                onReorder: onReorder,
                itemBuilder: (context, index) {
                  final displayNumber = index + 1;
                  final originalIndex = currentOrder[index];
                  final originalNumber = originalIndex + 1;
                  final thumbnail = thumbnails[originalIndex];

                  return Card(
                    key: ValueKey('page_$index'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 60,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: thumbnail != null && thumbnail.isNotEmpty
                            ? Image.memory(
                          thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.image, color: Colors.grey),
                            );
                          },
                        )
                            : const Center(
                          child: Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                      title: Text(
                        'Page $displayNumber',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Original: $originalNumber',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onApply;
  final VoidCallback onResetOrder;
  final bool hasChanges;

  const _ActionButtons({
    required this.isLoading,
    required this.onApply,
    required this.onResetOrder,
    required this.hasChanges,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading || !hasChanges ? null : onApply,
            icon: isLoading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.check),
            label: Text(isLoading ? 'Processing...' : 'Apply Reorder'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: !hasChanges ? null : onResetOrder,
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(100, 50),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ReorderedFileSection extends StatelessWidget {
  final String filePath;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  const _ReorderedFileSection({
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
              '✅ Reorder Complete!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('reordered.pdf'),
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