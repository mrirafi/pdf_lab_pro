import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_lab_pro/utils/file_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_lab_pro/providers/pdf_split_provider.dart';
import 'package:pdf_lab_pro/utils/constants.dart';
import 'package:pdf_lab_pro/services/pdf_split_service.dart';

class SplitPdfScreen extends ConsumerStatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  ConsumerState<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends ConsumerState<SplitPdfScreen> {
  final TextEditingController _rangeController = TextEditingController();
  final TextEditingController _nValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rangeController.addListener(() {
      ref.read(pdfSplitProvider.notifier).setPageRangeInput(_rangeController.text);
    });
    _nValueController.text = '2';
  }

  @override
  void dispose() {
    _rangeController.dispose();
    _nValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfSplitProvider);
    final notifier = ref.read(pdfSplitProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF', style: TextStyle(fontSize: 16)),
        actions: [
          if (state.pdfPath != null || state.outputFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: notifier.reset,
              tooltip: 'Reset All',
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

              // Split Mode Selection
              _buildSplitModeSelector(state, notifier),
              const SizedBox(height: 20),

              // Split Options
              _buildSplitOptions(state, notifier),
              const SizedBox(height: 20),

              // Split Button
              _buildSplitButton(state, notifier),
              const SizedBox(height: 20),
            ],

            // Status Messages
            if (state.error != null)
              _buildStatusMessage(
                state.error!,
                true,
                    () => notifier.clearError(),
              ),
            if (state.success != null)
              _buildStatusMessage(
                state.success!,
                false,
                    () => notifier.clearSuccess(),
              ),

            // Output Files
            if (state.outputFiles.isNotEmpty)
              _buildOutputFiles(state),

            // Tips Section
            _buildTipsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelection(PdfSplitState state, PdfSplitProvider notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.call_split, size: 48, color: Colors.blue),
            const SizedBox(height: 12),
            const Text(
              'Split PDF File',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Divide PDF into multiple files\nby pages, ranges, or size',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
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

  Widget _buildFileInfo(PdfSplitState state) {
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
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.pageCount ?? 0} pages • ${state.formattedOriginalSize}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(pdfSplitProvider.notifier).reset(),
              tooltip: 'Change PDF',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitModeSelector(PdfSplitState state, PdfSplitProvider notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Split Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...SplitMode.values.map((mode) {
              return RadioListTile<SplitMode>(
                title: Row(
                  children: [
                    Icon(mode.icon, size: 20),
                    const SizedBox(width: 8),
                    Text(mode.label),
                  ],
                ),
                subtitle: _getModeSubtitle(mode, state),
                value: mode,
                groupValue: state.splitMode,
                onChanged: (value) {
                  if (value != null) {
                    notifier.setSplitMode(value);
                    if (value == SplitMode.pageRange) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _rangeController.text = '1-${state.pageCount}';
                      });
                    }
                  }
                },
                dense: true,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget? _getModeSubtitle(SplitMode mode, PdfSplitState state) {
    final String? text;
    switch (mode) {
      case SplitMode.pageRange:
        text = 'e.g., 1-5, 8, 10-15';
        break;
      case SplitMode.everyNPages:
        final total = state.pageCount ?? 0;
        if (total > 0) {
          final parts = (total / state.nValue).ceil();
          text = 'Will create $parts file(s)';
        } else {
          text = null;
        }
        break;
      case SplitMode.singlePages:
        final total = state.pageCount ?? 0;
        text = total > 0 ? 'Will create $total individual files' : null;
        break;
    }

    return text != null ? Text(text) : null;
  }

  Widget _buildSplitOptions(PdfSplitState state, PdfSplitProvider notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Split Options',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            if (state.splitMode == SplitMode.pageRange) ...[
              TextField(
                controller: _rangeController,
                decoration: InputDecoration(
                  labelText: 'Page Ranges',
                  hintText: state.exampleText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.list),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => _showRangeHelp(),
                  ),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter ranges separated by commas: 1-3, 5, 7-9',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            if (state.splitMode == SplitMode.everyNPages) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Split every',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _nValueController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        final n = int.tryParse(value) ?? 2;
                        notifier.setNValue(n);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'pages',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.pageCount != null)
                Text(
                  'Will create ${(state.pageCount! / state.nValue).ceil()} file(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],

            if (state.splitMode == SplitMode.singlePages) ...[
              const Icon(Icons.view_array, size: 48, color: Colors.blue),
              const SizedBox(height: 12),
              Text(
                'Each page will be saved as individual PDF file',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              if (state.pageCount != null)
                Text(
                  '${state.pageCount} files will be created',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSplitButton(PdfSplitState state, PdfSplitProvider notifier) {
    bool isEnabled = true;
    String disabledReason = '';

    if (state.pdfPath == null) {
      isEnabled = false;
      disabledReason = 'Select a PDF file';
    } else if (state.splitMode == SplitMode.pageRange &&
        !state.hasValidPageRange) {
      isEnabled = false;
      disabledReason = 'Enter valid page ranges';
    } else if (state.splitMode == SplitMode.everyNPages &&
        (state.nValue < 2 || state.nValue > (state.pageCount ?? 1))) {
      isEnabled = false;
      disabledReason = 'N must be between 2 and ${state.pageCount}';
    }

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isEnabled && !state.isLoading
            ? () => notifier.splitPdf()
            : null,
        icon: state.isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.call_split),
        label: Text(
          state.isLoading
              ? 'Splitting...'
              : isEnabled
              ? 'Split PDF'
              : disabledReason,
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

  Widget _buildOutputFiles(PdfSplitState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Split Files',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.outputFiles.length} file(s)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...state.outputFiles.asMap().entries.map((entry) {
              final index = entry.key;
              final filePath = entry.value;
              final fileName = state.outputFileNames[index];
              final file = File(filePath);
              final size = file.lengthSync();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  title: Text(
                    fileName,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    FileUtils.formatFileSize(size),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        onPressed: () => _openFile(filePath),
                        tooltip: 'Open',
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, size: 18),
                        onPressed: () => _shareFile(filePath),
                        tooltip: 'Share',
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: state.outputFiles.length > 1
                  ? () => _shareAllFiles(state.outputFiles)
                  : null,
              icon: const Icon(Icons.share),
              label: const Text('Share All Files'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
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
                'Split Tips',
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
            '• Use page ranges for precise control (e.g., "1-3, 5, 7-9")\n'
                '• Split every N pages for equal sections\n'
                '• Single pages creates individual files for each page\n'
                '• Large PDFs may take longer to process',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPdf(PdfSplitProvider notifier) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await notifier.selectPdf(result.files.single.path!);
        // Set default range to all pages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _rangeController.text = '1-${ref.read(pdfSplitProvider).pageCount}';
        });
      }
    } catch (e) {
      _showError('Failed to select file: $e');
    }
  }

  void _showRangeHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Page Range Format'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Examples:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• 1-5 → Pages 1 through 5'),
              Text('• 1-3, 5, 7-9 → Pages 1-3, 5, 7-9'),
              Text('• 2,4,6 → Pages 2, 4, and 6'),
              Text('• 1 → Just page 1'),
              SizedBox(height: 12),
              Text(
                'Rules:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Use commas to separate ranges'),
              Text('• Use dash for continuous ranges'),
              Text('• Page numbers must be valid'),
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

  Future<void> _shareAllFiles(List<String> filePaths) async {
    try {
      final xFiles = filePaths.map((path) => XFile(path)).toList();
      await Share.shareXFiles(
        xFiles,
        text: 'Split PDF files from PDF Lab Pro',
        subject: 'Split PDF Files',
      );
    } catch (e) {
      _showError('Cannot share files: $e');
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
        title: const Text('Split PDF Guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Three Split Methods:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. **Page Ranges**: Split by specific pages/ranges'),
              Text('2. **Every N Pages**: Split into equal parts'),
              Text('3. **Single Pages**: Create individual files for each page'),
              SizedBox(height: 12),
              Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Preview original PDF to know page numbers'),
              Text('• Use page ranges for chapters/sections'),
              Text('• Single pages is great for extracting specific pages'),
              Text('• Large files may take time to process'),
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