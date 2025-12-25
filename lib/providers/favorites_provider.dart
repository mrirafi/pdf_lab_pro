import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_lab_pro/models/pdf_tool.dart';

class FavoritesState {
  final List<String> favoriteToolIds;
  final List<String> favoriteFilePaths;
  final bool isLoading;

  const FavoritesState({
    this.favoriteToolIds = const [],
    this.favoriteFilePaths = const [],
    this.isLoading = false,
  });

  FavoritesState copyWith({
    List<String>? favoriteToolIds,
    List<String>? favoriteFilePaths,
    bool? isLoading,
  }) {
    return FavoritesState(
      favoriteToolIds: favoriteToolIds ?? this.favoriteToolIds,
      favoriteFilePaths: favoriteFilePaths ?? this.favoriteFilePaths,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool isToolFavorite(String toolId) => favoriteToolIds.contains(toolId);
  bool isFileFavorite(String filePath) => favoriteFilePaths.contains(filePath);
}

class FavoritesProvider extends Notifier<FavoritesState> {
  static const String _toolsKey = 'favorite_tools';
  static const String _filesKey = 'favorite_files';

  @override
  FavoritesState build() {
    _loadFavorites();
    return const FavoritesState(isLoading: true);
  }

  // ADD THIS HELPER METHOD:
  List<PDFTool> getFavoriteTools(List<PDFTool> allTools) {
    return allTools.where(
            (tool) => state.favoriteToolIds.contains(tool.id)
    ).toList();
  }



  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final tools = prefs.getStringList(_toolsKey) ?? [];
    final files = prefs.getStringList(_filesKey) ?? [];

    state = state.copyWith(
      favoriteToolIds: tools,
      favoriteFilePaths: files,
      isLoading: false,
    );
  }

  Future<void> toggleToolFavorite(String toolId) async {
    final List<String> newFavorites;

    if (state.favoriteToolIds.contains(toolId)) {
      newFavorites = List.from(state.favoriteToolIds)..remove(toolId);
    } else {
      newFavorites = List.from(state.favoriteToolIds)..add(toolId);
    }

    state = state.copyWith(favoriteToolIds: newFavorites);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_toolsKey, newFavorites);
  }

  Future<void> toggleFileFavorite(String filePath) async {
    final List<String> newFavorites;

    if (state.favoriteFilePaths.contains(filePath)) {
      newFavorites = List.from(state.favoriteFilePaths)..remove(filePath);
    } else {
      newFavorites = List.from(state.favoriteFilePaths)..add(filePath);
    }

    state = state.copyWith(favoriteFilePaths: newFavorites);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_filesKey, newFavorites);
  }


  void clearAllFavorites() {
    state = const FavoritesState(isLoading: false);

    // Also clear from SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_toolsKey);
      prefs.remove(_filesKey);
    });
  }
}

final favoritesProvider = NotifierProvider<FavoritesProvider, FavoritesState>(
  FavoritesProvider.new,
);