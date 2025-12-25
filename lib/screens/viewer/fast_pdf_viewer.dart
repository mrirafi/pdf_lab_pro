import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:pdf_lab_pro/services/activity_tracker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_lab_pro/utils/constants.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_lab_pro/services/pdf_download_service.dart';


class FastPDFViewer extends ConsumerStatefulWidget {
  final String filePath;
  final String? title;
  final int? initialPage;

  const FastPDFViewer({
    super.key,
    required this.filePath,
    this.title,
    this.initialPage,
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

  // Simple bookmarks
  final Set<int> _bookmarks = <int>{};

  // UI visibility
  bool _showUi = true;

  bool _initialPageRestored = false;
  late final String _documentId;

  String get _bookmarksKey => 'bookmarks_$_documentId';
  String get _lastPageKey => 'lastPage_$_documentId';


  bool _onPdfGeneralTap(
      BuildContext context,
      PdfViewerController controller,
      PdfViewerGeneralTapHandlerDetails details,
      ) {
    // Toggle app bar + bottom bar just like Google Drive
    _toggleUi();

    // Return false so that PdfViewer can still handle taps
    // (links, text selection, etc. will continue to work)
    return false;
  }


  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();

    _fileName = widget.title ?? path.basename(widget.filePath);
    _documentId = path.basename(widget.filePath);

    _initFileInfo();
    _logViewActivity();

    _pdfController.addListener(_onPdfControllerChanged);
    _loadBookmarks();
  }

  Future<void> _logViewActivity() async {
    // Only log if this is a real PDF file (not a temporary merged file)
    if (widget.filePath.contains('merged') ||
        widget.filePath.contains('temp') ||
        widget.filePath.contains('converted')) {
      return;
    }

    await ActivityTracker.logActivity(
      type: ActivityType.view,
      title: 'Viewed PDF',
      description: 'Viewed $_fileName',
      filePath: widget.filePath,
      extraData: {
        'pageCount': _totalPages,
      },
    );
  }

  @override
  void dispose() {
    _pdfController.removeListener(_onPdfControllerChanged);
    super.dispose();
  }


  Future<void> _downloadCurrentPdf() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();

      final service = PdfDownloadService();
      final success = await service.saveWithSystemPicker(
        bytes: bytes,
        fileName: _fileName,
      );

      if (!success) {
        _showSnackBar('Download cancelled');
        return;
      }

      _showSnackBar('PDF saved successfully');
    } catch (e) {
      _showSnackBar('Download failed');
    }
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

    // Update state first
    setState(() {
      _isReady = true;
      _currentPage = pageNumber;
      _totalPages = pageCount;
    });

    // Handle initial page (from bookmark)
    if (!_initialPageRestored) {
      _initialPageRestored = true;

      // Priority 1: Initial page from bookmark
      if (widget.initialPage != null) {
        // Wait a bit then jump to bookmarked page
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future.delayed(const Duration(milliseconds: 500));
          await _goToInitialPage();
        });
      }
      // Priority 2: Last viewed page
      else {
        final prefs = await SharedPreferences.getInstance();
        final last = prefs.getInt(_lastPageKey);

        if (last != null && last >= 1 && last <= pageCount && last != pageNumber) {
          await _pdfController.goToPage(pageNumber: last);
        }
      }
    }

    // Save current page for future
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

  Future<bool> _handleWillPop() async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.push(RoutePaths.dashboard);
    }
    return false;
  }

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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$_totalPages pages',
                        style: TextStyle(
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
                                                TextStyle(
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
                                        style: TextStyle(
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${pages.length} item(s)',
                        style: TextStyle(
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
                          style: TextStyle(
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
              context.push(RoutePaths.dashboard);
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
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (_fileSize.isNotEmpty)
              Text(
                _fileSize,
                style: TextStyle(
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
                case 'download':
                  _downloadCurrentPdf();
                  break;
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
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 10),
                    Text('Download'),
                  ],
                ),
              ),

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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            IconButton(
              icon: const Icon(Icons.grid_view),
              tooltip: 'Pages thumbnail',
              onPressed: _showThumbnailsSheet,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentPage > 1
                  ? () => _goToPage(_currentPage - 1)
                  : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentPage < _totalPages
                  ? () => _goToPage(_currentPage + 1)
                  : null,
            ),
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,

        // IMPORTANT: SafeArea so PDF + app bar start *below* system status bar
        body: SafeArea(
          // keep bottom true as well so bottom bar is above gesture nav
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleUi, // tap anywhere, including over PDF, toggles UI
            child: Stack(
              children: [
                // Pdf viewer & scroll listener
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (_showUi) {
                        setState(() {
                          _showUi = false;
                        });
                      }
                      return false;
                    },
                    child: PdfViewer.file(
                      widget.filePath,
                      controller: _pdfController,
                      params: PdfViewerParams(
                        // Called on any tap on the PDF content
                        onGeneralTap: _onPdfGeneralTap,
                      ),

                    ),

                  ),
                ),

                // App bar (below status bar thanks to SafeArea)
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
                if (widget.initialPage != null && _isReady && _currentPage == widget.initialPage)
                  Positioned(
                    top: kToolbarHeight + 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _showUi ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bookmark, size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Bookmarked Page ${widget.initialPage}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // =====
              ],
            ),
          ),
        ),
      ),
    );
  }


// Update the _toggleBookmark method:
  Future<void> _toggleBookmark() async {
    if (!_isReady) return;
    final page = _currentPage;

    if (_bookmarks.contains(page)) {
      // Remove bookmark
      await _removeBookmark(page);
    } else {
      // Add bookmark with optional note
      _showAddBookmarkDialog(page);
    }
  }


  // Add bookmark with note dialog
  void _showAddBookmarkDialog(int page) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bookmark Page $page'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Add a note (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveBookmark(page, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

// Save bookmark with note
  Future<void> _saveBookmark(int page, String? note) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksKey = 'pdf_bookmarks_$_documentId';

    // Get existing bookmarks
    final bookmarksJson = prefs.getStringList(bookmarksKey) ?? [];

    // Create bookmark object
    final bookmark = {
      'page': page,
      'note': note ?? '',
      'timestamp': DateTime.now().toIso8601String(),
      'pdfName': _fileName,
      'pdfPath': widget.filePath,
    };

    // Check if already bookmarked
    final existingIndex = bookmarksJson.indexWhere((json) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map['page'] == page;
      } catch (e) {
        return false;
      }
    });

    if (existingIndex >= 0) {
      // Update existing
      bookmarksJson[existingIndex] = jsonEncode(bookmark);
    } else {
      // Add new
      bookmarksJson.add(jsonEncode(bookmark));
    }

    await prefs.setStringList(bookmarksKey, bookmarksJson);

    // Also save to global favorites
    await _saveToGlobalFavorites(bookmark);

    setState(() {
      _bookmarks.add(page);
    });

    _showSnackBar('Bookmarked page $page');
  }

// Save to global favorites
  Future<void> _saveToGlobalFavorites(Map<String, dynamic> bookmark) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesKey = 'global_favorites';

    final favoritesJson = prefs.getStringList(favoritesKey) ?? [];

    // Check if already in favorites
    final exists = favoritesJson.any((json) {
      try {
        final existing = jsonDecode(json) as Map<String, dynamic>;
        return existing['pdfPath'] == bookmark['pdfPath'] &&
            existing['page'] == bookmark['page'];
      } catch (e) {
        return false;
      }
    });

    if (!exists) {
      favoritesJson.add(jsonEncode(bookmark));
      await prefs.setStringList(favoritesKey, favoritesJson);
    }
  }

// Remove bookmark
  Future<void> _removeBookmark(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksKey = 'pdf_bookmarks_$_documentId';
    final favoritesKey = 'global_favorites';

    // Remove from document bookmarks
    final bookmarksJson = prefs.getStringList(bookmarksKey) ?? [];
    final newBookmarks = bookmarksJson.where((json) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map['page'] != page;
      } catch (e) {
        return true;
      }
    }).toList();

    await prefs.setStringList(bookmarksKey, newBookmarks);

    // Remove from global favorites
    final favoritesJson = prefs.getStringList(favoritesKey) ?? [];
    final newFavorites = favoritesJson.where((json) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return !(map['pdfPath'] == widget.filePath && map['page'] == page);
      } catch (e) {
        return true;
      }
    }).toList();

    await prefs.setStringList(favoritesKey, newFavorites);

    setState(() {
      _bookmarks.remove(page);
    });

    _showSnackBar('Removed bookmark from page $page');
  }

// Update the _loadBookmarks method:
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksKey = 'pdf_bookmarks_$_documentId';
    final stored = prefs.getStringList(bookmarksKey) ?? [];

    if (!mounted) return;

    setState(() {
      _bookmarks.clear();
      for (final json in stored) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          final page = map['page'] as int?;
          if (page != null && page > 0) {
            _bookmarks.add(page);
          }
        } catch (e) {
          // Skip invalid entries
        }
      }
    });
  }
// Add this method to _FastPDFViewerState class
  // Replace or update the _goToInitialPage method:
  Future<void> _goToInitialPage() async {
    if (widget.initialPage == null ||
        widget.initialPage! < 1 ||
        !_pdfController.isReady) {
      return;
    }

    // Keep trying until PDF is fully loaded
    int attempts = 0;
    while (attempts < 10) {
      attempts++;

      // Wait for PDF to be ready
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        if (_pdfController.isReady && _totalPages > 0) {
          // Ensure page is within bounds
          final targetPage = widget.initialPage!.clamp(1, _totalPages);

          await _pdfController.goToPage(pageNumber: targetPage);

          if (mounted) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📖 Jumped to bookmarked page $targetPage'),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          break; // Success, exit loop
        }
      } catch (e) {
        print('Error jumping to page: $e');
      }
    }
  }

}