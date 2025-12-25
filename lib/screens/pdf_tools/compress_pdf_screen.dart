import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_lab_pro/models/compress_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_lab_pro/providers/pdf_compress_provider.dart';
import 'package:pdf_lab_pro/utils/constants.dart';

class CompressPdfScreen extends ConsumerStatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  ConsumerState<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends ConsumerState<CompressPdfScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfCompressProvider);
    final notifier = ref.read(pdfCompressProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compress PDF', style: TextStyle(fontSize: 16)),
        actions: [
          if (state.pdfPath != null || state.compressedFilePath != null)
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File Selection
            if (state.pdfPath == null) ...[
              _buildFileSelection(state, notifier),
              const SizedBox(height: 20),
            ],

            if (state.pdfPath != null) ...[
              // File Info
              _buildFileInfo(state),
              const SizedBox(height: 20),

              // Compression Settings
              _buildCompressionSettings(state, notifier),
              const SizedBox(height: 20),

              // Compress Button
              _buildCompressButton(state, notifier),
              const SizedBox(height: 20),
            ],

            // Status Messages
            if (state.error != null)
              _buildStatusMessage(state.error!, true, () => notifier.clearError()),
            if (state.success != null)
              _buildStatusMessage(state.success!, false, () => notifier.clearSuccess()),

            // Results
            if (state.compressedFilePath != null)
              _buildResultsSection(state),

            // Tips
            _buildTipsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelection(PdfCompressState state, PdfCompressProvider notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.compress, size: 48, color: Colors.blue),
            const SizedBox(height: 12),
            Text(
              state.pdfPath == null
                  ? 'Select PDF to Compress'
                  : 'Selected: ${state.pdfName}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              state.pdfPath == null
                  ? 'Reduce file size while preserving quality'
                  : 'Size: ${state.formattedOriginalSize}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _pickPdf(notifier),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Select PDF File'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfo(PdfCompressState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.picture_as_pdf, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.pdfName ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Original: ${state.formattedOriginalSize}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompressionSettings(PdfCompressState state, PdfCompressProvider notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Compression Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Compression Level
            ...CompressionLevel.values.map((level) {
              return RadioListTile<CompressionLevel>(
                title: Text(level.label),
                subtitle: Text(level.description),
                value: level,
                groupValue: state.compressionLevel,
                onChanged: (value) => notifier.setCompressionLevel(value!),
                dense: true,
              );
            }).toList(),

            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),

            // Image Options

            if (state.compressionLevel != CompressionLevel.minimal) ...[
              ListTile(
                title: const Text('Quality'),
                subtitle: Slider(
                  value: state.imageQuality.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 9,
                  label: '${state.imageQuality}%',
                  onChanged: (value) => notifier.setImageQuality(value.toInt()),
                ),
                dense: true,
              ),
              SwitchListTile(
                title: const Text('Downscale Large Images'),
                subtitle: const Text('Reduce image dimensions while maintaining quality'),
                value: state.downscaleImages,
                onChanged: (value) => notifier.setDownscaleImages(value),
                dense: true,
              ),

            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompressButton(PdfCompressState state, PdfCompressProvider notifier) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: state.isLoading ? null : () => notifier.compressPdf(),
        icon: state.isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.compress),
        label: Text(
          state.isLoading ? 'Compressing...' : 'Compress PDF',
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessage(String message, bool isError, VoidCallback onClose) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red.shade200 : Colors.green.shade200,
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

  Widget _buildResultsSection(PdfCompressState state) {
    final originalSize = state.originalSize;
    final compressedSize = state.compressedSize ?? 0;
    final savings = originalSize > 0 ? (1 - compressedSize / originalSize) * 100 : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🎉 Compression Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Original',
                  state.formattedOriginalSize,
                  Colors.grey,
                ),
                _buildStatCard(
                  'Compressed',
                  state.formattedCompressedSize,
                  Colors.green,
                ),
                _buildStatCard(
                  'Savings',
                  '${savings.toStringAsFixed(1)}%',
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar
            LinearProgressIndicator(
              value: compressedSize / originalSize,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              'Size reduced by ${savings.toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openFile(state.compressedFilePath!),
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
                    onPressed: () => _shareFile(state.compressedFilePath!),
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

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTipsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Smart Compression Tips',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• Use "Medium" for balanced compression\n'
                '• Remove images for maximum size reduction\n'
                '• Downscale images >2MB for better results\n'
                '• Check compressed file quality before sharing',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPdf(PdfCompressProvider notifier) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await notifier.selectPdf(result.files.single.path!);
      }
    } catch (e) {
      _showError('Failed to select file: $e');
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
        title: const Text('PDF Compression Guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How PDF Compression Works:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• **Low**: Fast compression, keeps original quality'),
              Text('• **Medium**: Balanced size/quality (recommended)'),
              Text('• **High**: Maximum compression, reduces quality'),
              SizedBox(height: 12),
              Text(
                'Tips for Best Results:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('1. Scanned PDFs compress best'),
              Text('2. Remove images for maximum reduction'),
              Text('3. Always preview before sharing'),
              Text('4. Large files (>50MB) may take longer'),
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