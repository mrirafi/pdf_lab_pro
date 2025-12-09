import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_lab_pro/utils/constants.dart';
import 'package:go_router/go_router.dart';


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
  late final PdfViewerController _pdfController;

  bool _isReady = false;
  int _currentPage = 1;
  int _totalPages = 1;

  String _fileName = '';
  String _fileSize = '';

  // Simple in-memory bookmarks (page numbers)
  final Set<int> _bookmarks = <int>{};

  // UI visibility (for controls)
  bool _showUi = true;

  bool _initialPageRestored = false; // NEW
  late final String _documentId;

  String get _bookmarksKey => 'bookmarks_$_documentId';
  String get _lastPageKey => 'lastPage_$_documentId';

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();

    _fileName = widget.title ?? path.basename(widget.filePath);
    _documentId = path.basename(widget.filePath); // stable across copies with same name

    _initFileInfo();

    _pdfController.addListener(_onPdfControllerChanged);
    _loadBookmarks();
  }

  @override
  void dispose() {
    _pdfController.removeListener(_onPdfControllerChanged);
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_bookmarksKey) ?? [];
    if (!mounted) return;

    setState(() {
      _bookmarks
        ..clear()
        ..addAll(
          stored
              .map((e) => int.tryParse(e) ?? 0)
              .where((e) => e > 0),
        );
    });
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _bookmarksKey,
      _bookmarks.map((e) => e.toString()).toList(),
    );
  }




  Future<void> _initFileInfo() async {
    try {
      final file = File(widget.filePath);
      final stat = await file.stat();
      if (!mounted) return;
      setState(() {
        _fileSize = _formatFileSize(stat.size);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fileSize = '';
      });
    }
  }

  Future<void> _onPdfControllerChanged() async {
    if (!_pdfController.isReady) return;

    final pageNumber = _pdfController.pageNumber ?? 1;
    final pageCount = max(1, _pdfController.pageCount);

    if (!mounted) return;

    // First time we get a ready state: try to restore last page
    if (!_initialPageRestored) {
      _initialPageRestored = true;
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastPageKey);

      if (last != null && last >= 1 && last <= pageCount && last != pageNumber) {
        await _pdfController.goToPage(pageNumber: last);
        return; // wait for next controller callback
      }
    }

    setState(() {
      _isReady = true;
      _currentPage = pageNumber;
      _totalPages = pageCount;
    });

    // Save current page as last page
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPageKey, pageNumber);
  }



  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    final size = bytes / pow(1024, i);
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }

  void _toggleUi() {
    setState(() {
      _showUi = !_showUi;
    });
  }

  Future<void> _sharePDF() async {
    try {
      await Share.shareXFiles([XFile(widget.filePath)]);
    } catch (e) {
      _showSnackBar('Share failed: $e');
    }
  }

  Future<void> _openInOtherApp() async {
    try {
      await OpenFile.open(widget.filePath);
    } catch (e) {
      _showSnackBar('Open failed: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.primaryColor,
      ),
    );
  }

  Future<void> _goToPage(int pageNumber) async {
    if (!_pdfController.isReady) return;
    if (pageNumber < 1 || pageNumber > _totalPages) return;
    await _pdfController.goToPage(pageNumber: pageNumber);
  }

  // =========================
  // BACK BUTTON HANDLING
  // =========================
  Future<bool> _handleWillPop() async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.dashboard);
    }
    return false; // we handled the back action
  }


  // =========================
  // GO TO PAGE DIALOG (SEARCH)
  // =========================
  void _showGoToPageDialog() {
    if (!_isReady) return;
    final controller = TextEditingController(text: _currentPage.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Go to page'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Page number (1-$_totalPages)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (value) {
              final page = int.tryParse(value);
              if (page != null) {
                _goToPage(page);
              }
              Navigator.pop(ctx);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final page = int.tryParse(controller.text.trim());
                if (page != null) {
                  _goToPage(page);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  // =========================
  // THUMBNAIL SELECTOR
  // =========================
  void _showThumbnailsSheet() {
    if (!_isReady) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 310,
            child: Column(
              children: [
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Pages',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$_totalPages pages',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Use PdfDocumentViewBuilder.file to show real thumbnails
                Expanded(
                  child: PdfDocumentViewBuilder.file(
                    widget.filePath,
                    builder: (context, document) {
                      final pageCount =
                          document?.pages.length ?? _totalPages;

                      if (pageCount == 0) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: pageCount,
                        itemBuilder: (context, index) {
                          final pageNumber = index + 1;
                          final isCurrent = pageNumber == _currentPage;
                          final isBookmarked =
                          _bookmarks.contains(pageNumber);

                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _goToPage(pageNumber);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCurrent
                                      ? AppConstants.primaryColor
                                      : Colors.grey.shade300,
                                  width: isCurrent ? 1.5 : 1.0,
                                ),
                                boxShadow: isCurrent
                                    ? [
                                  BoxShadow(
                                    color: AppConstants.primaryColor
                                        .withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                                    : null,
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                          BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: document != null
                                            ? PdfPageView(
                                          document: document,
                                          pageNumber: pageNumber,
                                          alignment: Alignment.center,
                                        )
                                            : Center(
                                          child: Column(
                                            mainAxisSize:
                                            MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.picture_as_pdf,
                                                size: 24,
                                                color: isCurrent
                                                    ? AppConstants
                                                    .primaryColor
                                                    : Colors
                                                    .grey.shade400,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$pageNumber',
                                                style:
                                                GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  color: isCurrent
                                                      ? AppConstants
                                                      .primaryColor
                                                      : Colors
                                                      .grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Page $pageNumber',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      if (isBookmarked)
                                        const Icon(
                                          Icons.bookmark,
                                          size: 14,
                                          color: Colors.amber,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================
  // BOOKMARKS
  // =========================
  Future<void> _toggleBookmark() async {
    if (!_isReady) return;
    final page = _currentPage;

    setState(() {
      if (_bookmarks.contains(page)) {
        _bookmarks.remove(page);
        _showSnackBar('Removed bookmark from page $page');
      } else {
        _bookmarks.add(page);
        _showSnackBar('Bookmarked page $page');
      }
    });

    await _saveBookmarks();
  }


  void _showBookmarksSheet() {
    if (_bookmarks.isEmpty) {
      _showSnackBar('No bookmarks yet');
      return;
    }

    final pages = _bookmarks.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: min(320, 80.0 + pages.length * 56.0),
            child: Column(
              children: [
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Bookmarks',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${pages.length} item(s)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      final isCurrent = page == _currentPage;
                      return ListTile(
                        leading: Icon(
                          Icons.bookmark,
                          color: isCurrent
                              ? AppConstants.primaryColor
                              : Colors.amber,
                        ),
                        title: Text(
                          'Page $page',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _goToPage(page);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            setState(() {
                              _bookmarks.remove(page);
                            });
                            await _saveBookmarks();
                            Navigator.pop(ctx);
                            _showBookmarksSheet();
                          },
                        ),


                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================
  // APP BAR
  // =========================
  AnimatedOpacity _buildAppBar() {
    return AnimatedOpacity(
      opacity: _showUi ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: AppBar(
        backgroundColor: Colors.white.withOpacity(0.97),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RoutePaths.dashboard);
            }
          },
        ),

        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            // No page number on top. Show only file size (optional).
            if (_fileSize.isNotEmpty)
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
            icon: Icon(
              _bookmarks.contains(_currentPage)
                  ? Icons.bookmark
                  : Icons.bookmark_outline,
              color: _bookmarks.contains(_currentPage)
                  ? Colors.amber
                  : Colors.black87,
            ),
            tooltip: 'Toggle bookmark',
            onPressed: _toggleBookmark,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              switch (value) {
                case 'bookmarks':
                  _showBookmarksSheet();
                  break;
                case 'open':
                  _openInOtherApp();
                  break;
                case 'share':
                  _sharePDF();
                  break;
                case 'info':
                  _showDocumentInfo();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'bookmarks',
                child: Row(
                  children: [
                    Icon(Icons.bookmarks, size: 20),
                    SizedBox(width: 10),
                    Text('Bookmarks'),
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
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 10),
                    Text('Share'),
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
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Document information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow('File name', _fileName),
                _infoRow('File path', widget.filePath),
                if (_fileSize.isNotEmpty) _infoRow('File size', _fileSize),
                _infoRow('Pages', _isReady ? '$_totalPages' : 'Loading...'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // BOTTOM BAR
  // - Page number centered
  // - Page grid thumbnail & search icons in bottom
  // =========================
  Widget _buildBottomBar() {
    if (!_isReady) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _showUi ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade300,
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Page grid thumbnail button (bottom)
            IconButton(
              icon: const Icon(Icons.grid_view),
              tooltip: 'Pages thumbnail',
              onPressed: _showThumbnailsSheet,
            ),

            // Previous page
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentPage > 1
                  ? () => _goToPage(_currentPage - 1)
                  : null,
            ),

            // Centered page number
            Expanded(
              child: Center(
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Next page
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentPage < _totalPages
                  ? () => _goToPage(_currentPage + 1)
                  : null,
            ),

            // Search (go to page) at bottom
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Go to page',
              onPressed: _showGoToPageDialog,
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        // Tap ANYWHERE (over whole screen) to hide/unhide
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleUi,
          child: Stack(
            children: [
              // Pdf viewer with scroll listener to hide bars on scroll
              Positioned.fill(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // When user scrolls, hide the UI like Google Drive
                    if (_showUi) {
                      setState(() {
                        _showUi = false;
                      });
                    }
                    return false;
                  },
                  // Extra GestureDetector to ensure taps on PDF also toggle UI
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleUi,
                    child: PdfViewer.file(
                      widget.filePath,
                      controller: _pdfController,
                      params: const PdfViewerParams(
                        // Text selection (highlight) is enabled by default
                      ),
                    ),
                  ),
                ),
              ),

              // App bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildAppBar(),
              ),

              // Bottom bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
