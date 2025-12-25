import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_lab_pro/providers/pdf_to_image_provider.dart';
import 'package:pdf_lab_pro/services/pdf_to_image_service.dart';

class PdfToImageScreen extends ConsumerStatefulWidget {
  const PdfToImageScreen({super.key});

  @override
  ConsumerState<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends ConsumerState<PdfToImageScreen> {
  String? _pdfPath;
  String? _pdfName;
  ImageQuality _quality = ImageQuality.medium;
  int _totalPages = 0;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _pdfPath = result.files.single.path;
      _pdfName = result.files.single.name;
      _totalPages = 0;
    });

    if (_pdfPath != null) {
      try {
        final service = PdfToImageService();
        _totalPages = await service.getTotalPages(_pdfPath!);
        setState(() {});
      } catch (e) {
        print('Error getting pages: $e');
        _totalPages = 1;
        setState(() {});
      }
    }
  }

  Future<void> _convertPdf() async {
    if (_pdfPath == null) {
      _showSnackBar('Please select a PDF file first');
      return;
    }

    await ref.read(pdfToImageProvider.notifier).convertPdfToImages(
      pdfPath: _pdfPath!,
      pdfName: _pdfName ?? 'document',
      quality: _quality,
    );
  }

  Future<void> _downloadAllImages() async {
    await ref.read(pdfToImageProvider.notifier).downloadAllImages();
  }

  Future<void> _downloadSingleImage(String imagePath) async {
    await ref.read(pdfToImageProvider.notifier).downloadSingleImage(imagePath);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearImages() {
    ref.read(pdfToImageProvider.notifier).clearImages();
  }

  void _reset() {
    ref.read(pdfToImageProvider.notifier).reset();
    setState(() {
      _pdfPath = null;
      _pdfName = null;
      _totalPages = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfToImageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Image Converter', style: TextStyle(fontSize: 16)),
        actions: [
          if (state.images.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _clearImages,
              tooltip: 'Clear Images',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPdfSelection(state),
            const SizedBox(height: 20),
            if (_pdfPath != null) _buildConversionOptions(),
            const SizedBox(height: 20),
            _buildStatus(state),
            const SizedBox(height: 20),
            if (_pdfPath != null && !state.isLoading) _buildConvertButton(state),
            const SizedBox(height: 20),
            if (state.isLoading) _buildProgress(state),
            const SizedBox(height: 20),
            if (state.images.isNotEmpty) _buildImagesGrid(state),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfSelection(PdfToImageState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select PDF',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: state.isLoading ? null : _pickPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(_pdfName ?? 'Choose PDF File'),
              ),
            ),
            if (_pdfName != null) ...[
              const SizedBox(height: 8),
              if (_totalPages > 0)
                Text(
                  'Pages: $_totalPages',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversionOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Image Quality',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ImageQuality>(
              value: _quality,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Select Quality',
              ),
              items: ImageQuality.values.map((q) {
                return DropdownMenuItem(
                  value: q,
                  child: Text(q.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _quality = value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus(PdfToImageState state) {
    if (state.status.isEmpty) return const SizedBox();

    Color statusColor = Colors.blue;
    if (state.error != null) {
      statusColor = Colors.red;
    } else if (state.status.contains('✅')) {
      statusColor = Colors.green;
    } else if (state.status.contains('❌')) {
      statusColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Expanded(
            child: Text(
              state.status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConvertButton(PdfToImageState state) {
    return ElevatedButton.icon(
      onPressed: _convertPdf,
      icon: const Icon(Icons.image),
      label: const Text('Convert PDF to Images', style: TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildProgress(PdfToImageState state) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: state.totalPages > 0 ? state.currentPage / state.totalPages : null,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Processing page ${state.currentPage} of ${state.totalPages}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildImagesGrid(PdfToImageState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Converted Images (${state.images.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _downloadAllImages,
                icon: const Icon(Icons.download, size: 16, color: Colors.green),
                label: const Text('Download All',style: TextStyle(color: Colors.green),),
              ),
            ],
          ),
        ),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.65,
          ),
          itemCount: state.images.length,
          itemBuilder: (context, index) {
            final imagePath = state.images[index];
            final thumbnail = state.thumbnails[imagePath];

            return ImageThumbnailCard(
              imagePath: imagePath,
              thumbnail: thumbnail,
              pageNumber: index + 1,
              onDownload: () => _downloadSingleImage(imagePath),
              onView: () => _viewImage(imagePath),
            );
          },
        ),
      ],
    );
  }


  void _viewImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.file(
                File(imagePath),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 400,
                    height: 500,
                    color: Colors.grey.shade300,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, size: 50),
                        SizedBox(height: 10),
                        Text('Unable to display image'),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageThumbnailCard extends StatelessWidget {
  final String imagePath;
  final Uint8List? thumbnail;
  final int pageNumber;
  final VoidCallback onDownload;
  final VoidCallback onView;

  const ImageThumbnailCard({
    Key? key,
    required this.imagePath,
    required this.thumbnail,
    required this.pageNumber,
    required this.onDownload,
    required this.onView,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onView,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Thumbnail Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: Container(
                  color: Colors.grey.shade100,
                  child: thumbnail != null
                      ? Image.memory(
                    thumbnail!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholder();
                    },
                  )
                      : _buildPlaceholder(),
                ),
              ),
            ),

            // Bottom bar with actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$pageNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download, size: 16),
                    tooltip: 'Download',
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 30, color: Colors.grey.shade400),
          const SizedBox(height: 4),
          Text(
            'Page $pageNumber',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}