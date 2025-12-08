import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:pdf_lab_pro/services/pdf_extractor.dart';
import 'package:pdf_lab_pro/utils/constants.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

class FastPDFViewer extends ConsumerStatefulWidget {
  final String filePath;
  final String? title;

  const FastPDFViewer({
    super.key,
    required this.filePath,
    this.title,
  });

  @override
  ConsumerState<FastPDFViewer> createState() => _FastPDFViewerState();
}

class _FastPDFViewerState extends ConsumerState<FastPDFViewer> {
  bool _isLoading = true;
  String _fileName = '';
  String _fileSize = '';

  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _initMetadata();
    _startControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    super.dispose();
  }

  Future<void> _initMetadata() async {
    try {
      final metadata = await PdfExtractor.getMetadata(widget.filePath);
      setState(() {
        _fileName = metadata['name'] ?? path.basename(widget.filePath);
        _fileSize = metadata['readableSize'] ?? 'Unknown';
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _fileName = path.basename(widget.filePath);
        _fileSize = 'Unknown';
        _isLoading = false;
      });
    }
  }

  void _startControlsTimer() {
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    setState(() => _showControls = true);
    _startControlsTimer();
  }

  Future<void> _sharePDF() async {
    try {
      await Share.shareXFiles([XFile(widget.filePath)]);
    } catch (e) {
      _showSnackbar('Share failed: $e');
    }
  }

  Future<void> _openInOtherApp() async {
    try {
      await OpenFile.open(widget.filePath);
    } catch (e) {
      _showSnackbar('Open failed: $e');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildAppBar() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: AppBar(
        backgroundColor: Colors.white.withOpacity(0.97),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? _fileName,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _fileSize,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black87),
            onPressed: _sharePDF,
            tooltip: 'Share',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              switch (value) {
                case 'open':
                  _openInOtherApp();
                  break;
                case 'info':
                  _showDocumentInfo();
                  break;
                case 'print':
                  _showSnackbar('Print feature coming soon');
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 20),
                    SizedBox(width: 10),
                    Text('Open in other app'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 10),
                    Text('Document info'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print, size: 20),
                    SizedBox(width: 10),
                    Text('Print'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDocumentInfo() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Document Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('File name', _fileName),
              _buildInfoRow('File size', _fileSize),
              _buildInfoRow('Location', widget.filePath),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading PDF...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _fileName,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Minimal pdfrx viewer integration – high performance, built-in zoom/scroll
    return PdfViewer.file(
      widget.filePath,
      // We keep params minimal to stay compatible with v2.2.16
      params: const PdfViewerParams(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        onTap: _resetControlsTimer,
        onDoubleTap: _resetControlsTimer,
        child: Stack(
          children: [
            Positioned.fill(child: _buildPdfViewer()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildAppBar(),
            ),
          ],
        ),
      ),
    );
  }
}
