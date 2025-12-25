
import 'package:flutter_riverpod/legacy.dart';
import 'package:pdf_lab_pro/models/pdf_tool.dart';

bool initialDarkMode = false;

// Theme provider
final themeProvider = StateProvider<bool>((ref) => initialDarkMode);

// Navigation provider
final navigationIndexProvider = StateProvider<int>((ref) => 0);

// File selection provider
final selectedFilesProvider = StateProvider<List<String>>((ref) => []);

// PDF processing state provider
final isProcessingProvider = StateProvider<bool>((ref) => false);

// Recent tools provider - stores recently used tools
final recentToolsProvider = StateProvider<List<PDFTool>>((ref) => []);