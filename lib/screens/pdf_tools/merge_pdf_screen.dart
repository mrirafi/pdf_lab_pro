import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'package:pdf_lab_pro/providers/pdf_provider.dart';
import 'package:pdf_lab_pro/providers/file_provider.dart';
import 'package:pdf_lab_pro/utils/constants.dart';

class MergePdfScreen extends ConsumerStatefulWidget {
  const MergePdfScreen({super.key});

  @override
  ConsumerState<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends ConsumerState<MergePdfScreen> {
  @override
  Widget build(BuildContext context) {
    final pdfState = ref.watch(pdfProvider);
    final pdfNotifier = ref.read(pdfProvider.notifier);

    final isLoading = pdfState.isLoading;
    final selectedFiles = pdfState.selectedFiles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildHintCard(),
                  const SizedBox(height: 16),
                  _buildSelectButton(isLoading),
                  const SizedBox(height: 16),
                  Expanded(
                    child: selectedFiles.isEmpty
                        ? _buildEmptyState()
                        : _buildSelectedList(selectedFiles),
                  ),
                  const SizedBox(height: 8),
                  _buildMergeButton(
                    isLoading: isLoading,
                    canMerge: selectedFiles.length >= 2,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  // -----------------------------
  // UI pieces
  // -----------------------------

  Widget _buildHeader() {
    return Text(
      'Combine multiple PDFs into one file',
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildHintCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: AppConstants.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Select at least 2 PDF files. They will be merged in the same order as shown in the list.',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                height: 1.5,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : _pickFiles,
        icon: const Icon(Icons.add),
        label: Text(
          'Add PDF files',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: Colors.grey.shade400),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No PDF files selected yet.\nTap "Add PDF files" to get started.',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildSelectedList(List<String> files) {
    final pdfNotifier = ref.read(pdfProvider.notifier);

    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final pathStr = files[index];
        final name = p.basename(pathStr);

        return Dismissible(
          key: ValueKey(pathStr),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppConstants.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.delete_outline,
              color: AppConstants.errorColor,
            ),
          ),
          onDismissed: (_) {
            pdfNotifier.deselectFile(pathStr);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.picture_as_pdf,
                  color: AppConstants.primaryColor,
                  size: 22,
                ),
              ),
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                pathStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => pdfNotifier.deselectFile(pathStr),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMergeButton({
    required bool isLoading,
    required bool canMerge,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (!canMerge || isLoading) ? null : _onMergePressed,
        icon: const Icon(Icons.merge_type),
        label: Text(
          canMerge ? 'Merge PDFs' : 'Select at least 2 files',
          style: GoogleFonts.poppins(fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // -----------------------------
  // Actions
  // -----------------------------

  Future<void> _pickFiles() async {
    final pdfNotifier = ref.read(pdfProvider.notifier);

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf','jpeg','png','jpg'],
      );

      if (result == null || result.files.isEmpty) return;

      // You can decide: clear previous selection or append.
      // Here we append, which feels more natural for merge.
      for (final file in result.files) {
        final pathStr = file.path;
        if (pathStr != null && pathStr.toLowerCase().endsWith('.pdf')) {
          pdfNotifier.selectFile(pathStr);
        }
      }
    } catch (e) {
      _showSnackBar('Failed to select files: $e',
          color: AppConstants.errorColor);
    }
  }

  Future<void> _onMergePressed() async {
    final pdfNotifier = ref.read(pdfProvider.notifier);
    final fileNotifier = ref.read(fileProvider.notifier);

    final mergedPath = await pdfNotifier.mergeSelectedPdfsToFile();

    if (!mounted) return;

    if (mergedPath == null) {
      final error = ref.read(pdfProvider).error ?? 'Failed to merge PDFs';
      _showSnackBar(error, color: AppConstants.errorColor);
      return;
    }

    // Refresh recent files list
    await fileNotifier.loadRecentFiles();

    final name = p.basename(mergedPath);
    _showSnackBar(
      'Merged file created: $name',
      color: AppConstants.successColor,
    );

    // Open the merged file in your fast viewer
    final encodedPath = Uri.encodeComponent(mergedPath);
    final encodedTitle = Uri.encodeComponent(name);

    context.go(
      '${RoutePaths.viewPdf}?path=$encodedPath&title=$encodedTitle',
    );
  }

  void _showSnackBar(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? AppConstants.primaryColor,
      ),
    );
  }
}
