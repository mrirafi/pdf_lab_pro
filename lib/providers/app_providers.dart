// lib/providers/app_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// This will be set in main.dart BEFORE runApp
bool initialDarkMode = false;

// Theme provider
final themeProvider = StateProvider<bool>((ref) => initialDarkMode);

// Navigation provider
final navigationIndexProvider = StateProvider<int>((ref) => 0);

// File selection provider
final selectedFilesProvider = StateProvider<List<String>>((ref) => []);

// PDF processing state provider
final isProcessingProvider = StateProvider<bool>((ref) => false);
