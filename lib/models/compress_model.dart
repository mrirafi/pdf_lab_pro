// lib/models/compress_model.dart
import 'package:flutter/material.dart';

// Single source of truth for CompressionLevel
enum CompressionLevel {
  minimal('Minimal (5-10% Save)', 0.98, '...', Colors.green, 5, 10),
  light('Light (10-20% Save)', 0.92, '...', Colors.lightGreen, 10, 20),
  moderate('Moderate (30-40% Save)', 0.7, 'Good reduction, maintains quality', Colors.blue, 30, 40),
  aggressive('Aggressive (50-60% Save)', 0.5, 'Maximum useful reduction', Colors.orange, 50, 60),
  custom('Custom', 0.6, 'Manual settings', Colors.purple, 0, 80);

  final String label;
  final double quality; // Image quality multiplier (0-1)
  final String description;
  final Color color;
  final int minSavePercent;  // Minimum expected savings
  final int maxSavePercent;  // Maximum expected savings

  const CompressionLevel(
      this.label,
      this.quality,
      this.description,
      this.color,
      this.minSavePercent,
      this.maxSavePercent,
      );

  String get savingsRange => '$minSavePercent%-$maxSavePercent%';

  IconData get icon {
    switch (this) {
      case CompressionLevel.minimal:
        return Icons.speed_outlined;
      case CompressionLevel.light:
        return Icons.arrow_downward;
      case CompressionLevel.moderate:
        return Icons.compress;
      case CompressionLevel.aggressive:
        return Icons.bolt;
      case CompressionLevel.custom:
        return Icons.tune;
    }
  }
}

enum CompressionStrategy {
  recreate,
  direct,
}