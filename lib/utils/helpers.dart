import 'package:flutter/material.dart';

import 'package:pdf_lab_pro/utils/file_utils.dart';

class Helpers {
  // Deprecated - use FileUtils.formatFileSize instead
  static String formatFileSize(int bytes) {
    return FileUtils.formatFileSize(bytes);
  }

  // Deprecated - use FileUtils.formatDate instead
  static String formatDate(DateTime date) {
    return FileUtils.formatDate(date, relative: false);
  }

  // Additional helpers not related to file operations
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  static String truncateWithEllipsis(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static Color darkenColor(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  static Color lightenColor(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}