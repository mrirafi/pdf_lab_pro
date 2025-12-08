import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Theme provider
/// false = light theme, true = dark theme
final themeProvider = StateProvider<bool>((ref) => false);

/// Bottom navigation current index
final navigationIndexProvider = StateProvider<int>((ref) => 0);

/// Global selected files list (keep only if you actually use it)
final selectedFilesProvider = StateProvider<List<String>>((ref) => []);

/// Global processing flag (e.g. for showing a loader)
final isProcessingProvider = StateProvider<bool>((ref) => false);
