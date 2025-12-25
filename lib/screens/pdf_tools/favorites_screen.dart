import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pdf_lab_pro/utils/constants.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Bookmark> _favorites = [];
  bool _isLoading = true;
  String _sortBy = 'recent'; // 'recent', 'name', 'page'
  bool _groupByDocument = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList('global_favorites') ?? [];

      final favorites = favoritesJson.map((json) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          return Bookmark.fromJson(map);
        } catch (e) {
          return null;
        }
      }).whereType<Bookmark>().toList();

      // Sort favorites
      _sortFavorites(favorites);

      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading favorites: $e');
      setState(() => _isLoading = false);
    }
  }

  void _sortFavorites(List<Bookmark> favorites) {
    favorites.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return a.pdfName.compareTo(b.pdfName);
        case 'page':
          return a.page.compareTo(b.page);
        case 'recent':
        default:
          return b.timestamp.compareTo(a.timestamp);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: 'Sort',
          ),
          IconButton(
            icon: Icon(_groupByDocument ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() => _groupByDocument = !_groupByDocument);
            },
            tooltip: _groupByDocument ? 'List view' : 'Group by document',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading(theme)
          : _buildContent(theme),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading bookmarks...',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_favorites.isEmpty) {
      return _buildEmptyState(theme);
    }

    if (_groupByDocument) {
      return _buildGroupedView(theme);
    } else {
      return _buildListView(theme);
    }
  }

  Widget _buildGroupedView(ThemeData theme) {
    // Group favorites by PDF document
    final Map<String, List<Bookmark>> grouped = {};

    for (final bookmark in _favorites) {
      final key = '${bookmark.pdfPath}|${bookmark.pdfName}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(bookmark);
    }

    return ListView(
      children: [
        // Statistics
        _buildStatsCard(theme),

        // Grouped bookmarks
        ...grouped.entries.map((entry) {
          final bookmarks = entry.value;
          final firstBookmark = bookmarks.first;
          final file = File(firstBookmark.pdfPath);
          final exists = file.existsSync();

          return Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Document header
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: exists ? Colors.red.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf,
                      color: exists ? Colors.red : Colors.grey,
                    ),
                  ),
                  title: Text(
                    firstBookmark.pdfName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${bookmarks.length} bookmark${bookmarks.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: exists ? () => _openPdf(firstBookmark.pdfPath) : null,
                    tooltip: 'Open PDF',
                  ),
                ),

                // Bookmarks list
                ...bookmarks.map((bookmark) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: theme.dividerColor.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 72, right: 8),
                      title: Text(
                        'Page ${bookmark.page}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: bookmark.note.isNotEmpty
                          ? Text(
                        bookmark.note,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.open_in_browser, size: 18),
                            onPressed: () => _openBookmark(bookmark),
                            tooltip: 'Go to page',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _removeBookmark(bookmark),
                            tooltip: 'Remove bookmark',
                          ),
                        ],
                      ),
                      onTap: () => _openBookmark(bookmark),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildListView(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView(
        children: [
          // Statistics
          _buildStatsCard(theme),

          // All bookmarks list
          ..._favorites.map((bookmark) {
            final file = File(bookmark.pdfPath);
            final exists = file.existsSync();

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bookmark.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bookmark,
                    color: bookmark.color,
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookmark.pdfName,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Page ${bookmark.page}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                subtitle: bookmark.note.isNotEmpty
                    ? Text(
                  bookmark.note,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bookmark.timeAgo,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _removeBookmark(bookmark),
                      tooltip: 'Remove bookmark',
                    ),
                  ],
                ),
                onTap: () => _openBookmark(bookmark),
                onLongPress: () => _showBookmarkOptions(bookmark),
              ),
            );
          }).toList(),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final totalBookmarks = _favorites.length;
    final totalDocuments = _favorites
        .map((b) => b.pdfPath)
        .toSet()
        .length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          _buildStatItem(
            'Bookmarks',
            totalBookmarks.toString(),
            Icons.bookmark,
            Colors.amber,
            theme,
          ),
          const SizedBox(width: 24),
          _buildStatItem(
            'Documents',
            totalDocuments.toString(),
            Icons.picture_as_pdf,
            Colors.red,
            theme,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAllFavorites,
            tooltip: 'Clear all bookmarks',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label,
      String value,
      IconData icon,
      Color color,
      ThemeData theme,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'No bookmarks yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Bookmark important pages while reading PDFs.\nThey will appear here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Open a PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBookmark(Bookmark bookmark) async {
    final file = File(bookmark.pdfPath);

    if (!await file.exists()) {
      _showError('PDF file not found: ${bookmark.pdfName}');
      return;
    }

    // Navigate to PDF viewer at the bookmarked page
    context.go(
      '${RoutePaths.viewPdf}?path=${Uri.encodeComponent(bookmark.pdfPath)}'
          '&title=${Uri.encodeComponent(bookmark.pdfName)}'
          '&page=${bookmark.page}', // Add page parameter
    );

    // Optional: Show a brief loading message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening page ${bookmark.page}...'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openPdf(String pdfPath) async {
    final fileName = p.basename(pdfPath);
    context.push(
      '${RoutePaths.viewPdf}?path=${Uri.encodeComponent(pdfPath)}'
          '&title=${Uri.encodeComponent(fileName)}',
    );
  }

  Future<void> _removeBookmark(Bookmark bookmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Bookmark'),
        content: Text('Remove bookmark from page ${bookmark.page}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: TextStyle(color: AppConstants.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Remove from global favorites
        final prefs = await SharedPreferences.getInstance();
        final favoritesKey = 'global_favorites';
        final favoritesJson = prefs.getStringList(favoritesKey) ?? [];

        final newFavorites = favoritesJson.where((json) {
          try {
            final map = jsonDecode(json) as Map<String, dynamic>;
            return !(map['pdfPath'] == bookmark.pdfPath &&
                map['page'] == bookmark.page);
          } catch (e) {
            return true;
          }
        }).toList();

        await prefs.setStringList(favoritesKey, newFavorites);

        // Also remove from document-specific bookmarks
        final docKey = 'pdf_bookmarks_${p.basename(bookmark.pdfPath)}';
        final docBookmarksJson = prefs.getStringList(docKey) ?? [];
        final newDocBookmarks = docBookmarksJson.where((json) {
          try {
            final map = jsonDecode(json) as Map<String, dynamic>;
            return map['page'] != bookmark.page;
          } catch (e) {
            return true;
          }
        }).toList();

        await prefs.setStringList(docKey, newDocBookmarks);

        // Reload favorites
        await _loadFavorites();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bookmark removed'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        _showError('Failed to remove bookmark: $e');
      }
    }
  }

  void _showBookmarkOptions(Bookmark bookmark) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Go to Page'),
              onTap: () {
                Navigator.pop(context);
                _openBookmark(bookmark);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Edit Note'),
              onTap: () {
                Navigator.pop(context);
                _editBookmarkNote(bookmark);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareBookmark(bookmark);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Remove Bookmark', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _removeBookmark(bookmark);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBookmarkNote(Bookmark bookmark) async {
    final controller = TextEditingController(text: bookmark.note);

    final newNote = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Note - Page ${bookmark.page}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Add or edit note...',
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
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newNote != null && newNote != bookmark.note) {
      await _updateBookmarkNote(bookmark, newNote);
    }
  }

  Future<void> _updateBookmarkNote(Bookmark bookmark, String newNote) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesKey = 'global_favorites';
      final favoritesJson = prefs.getStringList(favoritesKey) ?? [];

      final updatedFavorites = favoritesJson.map((json) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          if (map['pdfPath'] == bookmark.pdfPath && map['page'] == bookmark.page) {
            map['note'] = newNote;
            map['timestamp'] = DateTime.now().toIso8601String();
          }
          return jsonEncode(map);
        } catch (e) {
          return json;
        }
      }).toList();

      await prefs.setStringList(favoritesKey, updatedFavorites);

      // Also update in document-specific bookmarks
      final docKey = 'pdf_bookmarks_${p.basename(bookmark.pdfPath)}';
      final docBookmarksJson = prefs.getStringList(docKey) ?? [];
      final updatedDocBookmarks = docBookmarksJson.map((json) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          if (map['page'] == bookmark.page) {
            map['note'] = newNote;
            map['timestamp'] = DateTime.now().toIso8601String();
          }
          return jsonEncode(map);
        } catch (e) {
          return json;
        }
      }).toList();

      await prefs.setStringList(docKey, updatedDocBookmarks);

      await _loadFavorites();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Failed to update note: $e');
    }
  }

  Future<void> _shareBookmark(Bookmark bookmark) async {
    final file = File(bookmark.pdfPath);

    if (!await file.exists()) {
      _showError('PDF file not found');
      return;
    }

    // TODO: Implement sharing with note
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon')),
    );
  }

  Future<void> _clearAllFavorites() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Bookmarks'),
        content: const Text('Remove all bookmarks? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear All',
              style: TextStyle(color: AppConstants.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Clear global favorites
        await prefs.remove('global_favorites');

        // Clear all document-specific bookmarks
        final keys = prefs.getKeys().where((key) => key.startsWith('pdf_bookmarks_'));
        for (final key in keys) {
          await prefs.remove(key);
        }

        await _loadFavorites();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All bookmarks cleared'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        _showError('Failed to clear bookmarks: $e');
      }
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sort Bookmarks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            RadioListTile<String>(
              title: const Text('Most Recent'),
              value: 'recent',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                _sortFavorites(_favorites);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Document Name'),
              value: 'name',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                _sortFavorites(_favorites);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Page Number'),
              value: 'page',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                _sortFavorites(_favorites);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Bookmark Model
class Bookmark {
  final int page;
  final String note;
  final DateTime timestamp;
  final String pdfName;
  final String pdfPath;

  Bookmark({
    required this.page,
    required this.note,
    required this.timestamp,
    required this.pdfName,
    required this.pdfPath,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      page: json['page'] as int? ?? 1,
      note: json['note'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      pdfName: json['pdfName'] as String? ?? 'Unknown PDF',
      pdfPath: json['pdfPath'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
      'pdfName': pdfName,
      'pdfPath': pdfPath,
    };
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  Color get color {
    // Generate consistent color based on PDF path
    final hash = pdfPath.hashCode;
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[hash.abs() % colors.length];
  }
}