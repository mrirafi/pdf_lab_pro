import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/pdf_tool.dart';
import 'package:pdf_lab_pro/utils/constants.dart';


class AllToolsScreen extends ConsumerStatefulWidget {
  const AllToolsScreen({super.key});

  @override
  ConsumerState<AllToolsScreen> createState() => _AllToolsScreenState();
}

class _AllToolsScreenState extends ConsumerState<AllToolsScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<PDFTool?> _pressedToolNotifier = ValueNotifier(null);

  @override
  void dispose() {
    _searchController.dispose();
    _pressedToolNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseTools = _selectedCategory == 'All'
        ? PDFToolsData.allTools
        : PDFToolsData.getToolsByCategory(_selectedCategory);

    final filteredTools = baseTools.where((tool) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return tool.title.toLowerCase().contains(q) ||
          tool.category.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All PDF Tools',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${filteredTools.length} tools · Smart Toolbox',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(context),
            _buildCategoryFilter(),
            const SizedBox(height: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildToolsGrid(filteredTools),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------
  // SEARCH BAR
  // ------------------------
  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim();
          });
        },
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search tools (merge, convert, share...)',
          hintStyle: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
          prefixIcon: const Icon(Icons.search, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ------------------------
  // CATEGORY FILTER
  // ------------------------
  Widget _buildCategoryFilter() {
    final categories = ['All', ...PDFToolsData.categories];

    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: EdgeInsets.only(
              right: index < categories.length - 1 ? 8 : 0,
            ),
            child: ChoiceChip(
              label: Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              pressElevation: 0,
              backgroundColor: Colors.grey.shade100,
              selectedColor: const Color(0xFF2196F3).withOpacity(0.12),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color:
                isSelected ? const Color(0xFF2196F3) : Colors.grey.shade700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF2196F3)
                      : Colors.grey.shade300,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------
  // RESPONSIVE GRID
  // ------------------------
  Widget _buildToolsGrid(List<PDFTool> tools) {
    if (tools.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'No tools found',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different keyword or category.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 3;

        if (width < 340) {
          crossAxisCount = 2;
        } else if (width > 600) {
          crossAxisCount = 4;
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: GridView.builder(
            key: ValueKey('${_selectedCategory}_$_searchQuery${tools.length}'),
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.9,
            ),
            itemCount: tools.length,
            itemBuilder: (context, index) {
              final tool = tools[index];
              return _ToolCard(
                tool: tool,
                onTap: () => _navigateToTool(tool),
              );
            },
          ),
        );
      },
    );
  }

  // ------------------------
  // NAVIGATION / ACTION
  // ------------------------
  void _navigateToTool(PDFTool tool) {
    switch (tool.id) {
      case 'view_pdf':
      // Open file picker for PDF viewer
        break;
      case 'merge_pdf':
        context.push(RoutePaths.mergePdf);
        break;
      case 'split_pdf':
        context.push(RoutePaths.splitPdf);
        break;
      case 'compress_pdf':
        context.push(RoutePaths.compressPdf);
        break;
      case 'extract_pages':
        context.push(RoutePaths.extractPages);
        break;
      case 'reorder_pages':
        context.push(RoutePaths.reorderPages);
        break;
      case 'pdf_to_image':
        context.push(RoutePaths.pdfToImage);
        break;
      case 'image_to_pdf':
        context.push(RoutePaths.imageToPdf);
        break;
      case 'protect_pdf':
        context.push(RoutePaths.protectPdf);
        break;
      case 'watermark':
        context.push(RoutePaths.watermarkPdf);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tool.title} feature coming soon!'),
            duration: const Duration(milliseconds: 500),
          ),
        );
    }
  }
}

// ==========================================
// REUSABLE TOOL CARD WIDGET (BETTER UX)
// ==========================================
class _ToolCard extends StatelessWidget {
  final PDFTool tool;
  final VoidCallback onTap;

  const _ToolCard({
    required this.tool,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashFactory: InkRipple.splashFactory,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                tool.color.withOpacity(0.16),
                theme.colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: tool.color.withOpacity(0.25),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: tool.color.withOpacity(0.32),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Centered Icon Bubble
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tool.color.withOpacity(0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  tool.icon,
                  color: tool.color,
                  size: 34,
                ),
              ),

              const SizedBox(height: 14),

              // Title
              Text(
                tool.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Subtle hint
              Text(
                'Tap to open',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: tool.color.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

