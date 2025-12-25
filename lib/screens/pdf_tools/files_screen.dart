import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:pdf_lab_pro/providers/file_provider.dart';
import 'package:pdf_lab_pro/services/activity_tracker.dart';
import 'package:pdf_lab_pro/utils/constants.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  List<Activity> _activities = [];
  ActivityStats? _stats;
  bool _isLoading = true;
  ActivityType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);

    try {
      final activities = await ActivityTracker.getActivities();
      final stats = await ActivityTracker.getStats();

      if (mounted) {
        setState(() {
          _activities = activities;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredActivities = _filterType == null
        ? _activities
        : _activities.where((a) => a.type == _filterType).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        actions: [
          if (_stats != null) ...[
            IconButton(
              icon: const Icon(Icons.insights),
              onPressed: _showStats,
              tooltip: 'Statistics',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearHistory,
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading(theme)
          : _buildContent(theme, filteredActivities),
      floatingActionButton: _filterType != null
          ? FloatingActionButton(
              onPressed: () {
                setState(() => _filterType = null);
              },
              tooltip: 'Clear Filter',
              child: const Icon(Icons.clear_all),
            )
          : null,
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
            'Loading history...',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    List<Activity> activities,
  ) {

    return RefreshIndicator(
      onRefresh: _loadActivities,
      child: CustomScrollView(
        slivers: [
          // Statistics Card
          if (_stats != null && _filterType == null)
            SliverToBoxAdapter(
              child: _buildStatsCard(theme),
            ),

          // Filter Indicator
          if (_filterType != null)
            SliverToBoxAdapter(
              child: _buildFilterIndicator(theme),
            ),

          // Activity History Section
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              _filterType != null ? 'Filtered Activities' : 'Recent Activity',
              theme,
            ),
          ),
          if (activities.isEmpty)
            SliverToBoxAdapter(
              child: _buildNoActivities(theme),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final activity = activities[index];
                  return _ActivityItemCard(
                    activity: activity,
                    theme: theme,
                    onTap: () => _handleActivityTap(activity),
                    onDelete: () => _deleteActivity(activity.id),
                  );
                },
                childCount: activities.length,
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    if (_stats == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(77),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withAlpha(51),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 18),
              const SizedBox(width: 8),
              Text(
                'Activity Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${_stats!.totalActivities} total',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'PDF Ops',
                _stats!.pdfOperations.toString(),
                Colors.blue,
                theme,
              ),
              _buildStatItem(
                'Conversions',
                _stats!.conversionOperations.toString(),
                Colors.green,
                theme,
              ),
              _buildStatItem(
                'Security',
                _stats!.securityOperations.toString(),
                Colors.red,
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withAlpha(153),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterIndicator(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _filterType!.color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _filterType!.color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_filterType!.icon, size: 16, color: _filterType!.color),
          const SizedBox(width: 8),
          Text(
            _filterType!.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _filterType!.color,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _filterType = null),
            child: Icon(Icons.close, size: 16, color: _filterType!.color),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: theme.colorScheme.onSurface.withAlpha(77),
          ),
          const SizedBox(height: 20),
          Text(
            'No history yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your PDF operations will appear here',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withAlpha(102),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push(RoutePaths.allTools),
            icon: const Icon(Icons.explore),
            label: const Text('Try PDF Tools'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActivities(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.filter_list,
            size: 48,
            color: theme.colorScheme.onSurface.withAlpha(77),
          ),
          const SizedBox(height: 16),
          Text(
            'No activities found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterType != null
                ? 'Try changing or clearing the filter'
                : 'Complete some PDF operations first',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  void _openFile(String filePath) {
    final fileName = p.basename(filePath);
    context.push(
      '${RoutePaths.viewPdf}?path=${Uri.encodeComponent(filePath)}'
      '&title=${Uri.encodeComponent(fileName)}',
    );
  }

  void _showFileOptions(String filePath) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                _openFile(filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareFile(filePath);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppConstants.errorColor),
              title: Text(
                'Delete',
                style: TextStyle(color: AppConstants.errorColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteFile(filePath);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteFile(String filePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: const Text('Are you sure you want to delete this file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppConstants.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(fileProvider.notifier).deleteFile(filePath);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File deleted'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleActivityTap(Activity activity) {
    if (activity.filePath != null && activity.filePath!.isNotEmpty) {
      final file = File(activity.filePath!);
      if (file.existsSync()) {
        _openFile(activity.filePath!);
      } else {
        _showActivityDetails(activity);
      }
    } else {
      _showActivityDetails(activity);
    }
  }

  void _showActivityDetails(Activity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(activity.type.icon, color: activity.type.color),
            const SizedBox(width: 12),
            Expanded(child: Text(activity.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(activity.description),
            const SizedBox(height: 8),
            if (activity.filePath != null) ...[
              const SizedBox(height: 8),
              Text(
                'File: ${p.basename(activity.filePath!)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Time: ${activity.timeAgo}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (activity.filePath != null && activity.filePath!.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _handleActivityTap(activity);
              },
              child: const Text('Open File'),
            ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Filter Activities',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...ActivityType.values.map((type) {
                final count = _activities.where((a) => a.type == type).length;
                return ListTile(
                  leading: Icon(type.icon, color: type.color),
                  title: Text(type.label),
                  trailing: Text(
                    count.toString(),
                    style: TextStyle(
                      color: type.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _filterType = type);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showStats() {
    if (_stats == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activity Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Activities', _stats!.totalActivities.toString()),
            _buildStatRow('PDF Operations', _stats!.pdfOperations.toString()),
            _buildStatRow('Conversions', _stats!.conversionOperations.toString()),
            _buildStatRow('Security Operations', _stats!.securityOperations.toString()),
            const SizedBox(height: 16),
            if (_stats!.lastActivity != null)
              Text(
                'Last activity: ${_formatTime(_stats!.lastActivity!)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Clear all activity history? This cannot be undone.'),
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
      await ActivityTracker.clearActivities();
      await _loadActivities();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('History cleared'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteActivity(String activityId) async {
    await ActivityTracker.deleteActivity(activityId);
    await _loadActivities();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activity removed'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

// Activity Item Card Widget
class _ActivityItemCard extends StatelessWidget {
  final Activity activity;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ActivityItemCard({
    required this.activity,
    required this.theme,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withAlpha(26),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: activity.type.color.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(activity.type.icon, color: activity.type.color),
        ),
        title: Text(
          activity.title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              activity.description,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              activity.timeAgo,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withAlpha(102),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: theme.colorScheme.onSurface.withAlpha(77),
          ),
          onSelected: (value) {
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18),
                  SizedBox(width: 8),
                  Text('Remove from history'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
