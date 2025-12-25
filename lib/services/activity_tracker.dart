import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ActivityTracker {
  static const String _activitiesKey = 'user_activities';
  static const int _maxActivities = 100; // Store up to 100 activities

  /// Log a new activity
  static Future<void> logActivity({
    required ActivityType type,
    required String title,
    required String description,
    String? filePath,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activitiesJson = prefs.getStringList(_activitiesKey) ?? [];

      final activity = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': type.name,
        'title': title,
        'description': description,
        'filePath': filePath,
        'extraData': extraData,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Add to beginning of list (most recent first)
      activitiesJson.insert(0, jsonEncode(activity));

      // Keep only recent activities to prevent storage issues
      if (activitiesJson.length > _maxActivities) {
        activitiesJson.removeLast();
      }

      await prefs.setStringList(_activitiesKey, activitiesJson);

      print('✅ Activity logged: $type - $title');
    } catch (e) {
      print('❌ Failed to log activity: $e');
    }
  }

  /// Get all activities sorted by most recent
  static Future<List<Activity>> getActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activitiesJson = prefs.getStringList(_activitiesKey) ?? [];

      final activities = activitiesJson.map((json) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          return Activity.fromJson(map);
        } catch (e) {
          print('❌ Error parsing activity JSON: $e');
          return null;
        }
      }).whereType<Activity>().toList();

      return activities;
    } catch (e) {
      print('❌ Failed to get activities: $e');
      return [];
    }
  }

  /// Clear all activities
  static Future<void> clearActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activitiesKey);
      print('✅ All activities cleared');
    } catch (e) {
      print('❌ Failed to clear activities: $e');
    }
  }

  /// Delete a specific activity by ID
  static Future<void> deleteActivity(String activityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activitiesJson = prefs.getStringList(_activitiesKey) ?? [];

      final newActivities = activitiesJson.where((json) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          return map['id'] != activityId;
        } catch (e) {
          return true;
        }
      }).toList();

      await prefs.setStringList(_activitiesKey, newActivities);
      print('✅ Activity deleted: $activityId');
    } catch (e) {
      print('❌ Failed to delete activity: $e');
    }
  }

  /// Get activities filtered by type
  static Future<List<Activity>> getActivitiesByType(ActivityType type) async {
    final allActivities = await getActivities();
    return allActivities.where((activity) => activity.type == type).toList();
  }

  /// Get statistics about activities
  static Future<ActivityStats> getStats() async {
    final activities = await getActivities();

    int totalFiles = 0;
    int pdfOperations = 0;
    int conversionOperations = 0;
    int securityOperations = 0;

    for (final activity in activities) {
      totalFiles++;

      switch (activity.type) {
        case ActivityType.merge:
        case ActivityType.split:
        case ActivityType.compress:
        case ActivityType.reorder:
          pdfOperations++;
          break;
        case ActivityType.pdfToImage:
        case ActivityType.imageToPdf:
        case ActivityType.pdfToWord:
        case ActivityType.wordToPdf:
          conversionOperations++;
          break;
        case ActivityType.protect:
        case ActivityType.watermark:
          securityOperations++;
          break;
        default:
          break;
      }
    }

    return ActivityStats(
      totalActivities: totalFiles,
      pdfOperations: pdfOperations,
      conversionOperations: conversionOperations,
      securityOperations: securityOperations,
      lastActivity: activities.isNotEmpty ? activities.first.timestamp : null,
    );
  }
}

/// Activity types enum
enum ActivityType {
  merge('Merge PDF'),
  split('Split PDF'),
  compress('Compress PDF'),
  reorder('Reorder Pages'),
  pdfToImage('PDF to Images'),
  imageToPdf('Images to PDF'),
  pdfToWord('PDF to Word'),
  wordToPdf('Word to PDF'),
  protect('Protect PDF'),
  watermark('Watermark PDF'),
  extract('Extract Pages'),
  rotate('Rotate PDF'),
  view('View PDF'),
  other('Other Operation');

  final String label;
  const ActivityType(this.label);

  IconData get icon {
    switch (this) {
      case ActivityType.merge:
        return Icons.merge;
      case ActivityType.split:
        return Icons.call_split;
      case ActivityType.compress:
        return Icons.compress;
      case ActivityType.reorder:
        return Icons.reorder;
      case ActivityType.pdfToImage:
        return Icons.image;
      case ActivityType.imageToPdf:
        return Icons.picture_as_pdf;
      case ActivityType.pdfToWord:
        return Icons.description;
      case ActivityType.wordToPdf:
        return Icons.picture_as_pdf;
      case ActivityType.protect:
        return Icons.lock;
      case ActivityType.watermark:
        return Icons.water_damage;
      case ActivityType.extract:
        return Icons.content_cut;
      case ActivityType.rotate:
        return Icons.rotate_90_degrees_ccw;
      case ActivityType.view:
        return Icons.visibility;
      default:
        return Icons.history;
    }
  }

  Color get color {
    switch (this) {
      case ActivityType.merge:
      case ActivityType.split:
      case ActivityType.compress:
      case ActivityType.reorder:
        return Colors.blue; // Organize tools
      case ActivityType.pdfToImage:
      case ActivityType.imageToPdf:
      case ActivityType.pdfToWord:
      case ActivityType.wordToPdf:
        return Colors.green; // Conversion tools
      case ActivityType.protect:
      case ActivityType.watermark:
        return Colors.red; // Security tools
      case ActivityType.extract:
      case ActivityType.rotate:
        return Colors.orange; // Other tools
      case ActivityType.view:
        return Colors.purple; // View tool
      default:
        return Colors.grey;
    }
  }
}

/// Activity model
class Activity {
  final String id;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? filePath;
  final Map<String, dynamic>? extraData;

  Activity({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.filePath,
    this.extraData,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String? ?? '',
      type: ActivityType.values.firstWhere(
            (type) => type.name == json['type'],
        orElse: () => ActivityType.other,
      ),
      title: json['title'] as String? ?? 'Unknown Activity',
      description: json['description'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      filePath: json['filePath'] as String?,
      extraData: json['extraData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'filePath': filePath,
      'extraData': extraData,
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
}

/// Activity statistics
class ActivityStats {
  final int totalActivities;
  final int pdfOperations;
  final int conversionOperations;
  final int securityOperations;
  final DateTime? lastActivity;

  const ActivityStats({
    required this.totalActivities,
    required this.pdfOperations,
    required this.conversionOperations,
    required this.securityOperations,
    this.lastActivity,
  });
}
