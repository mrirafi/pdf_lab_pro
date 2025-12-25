import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import 'package:pdf_lab_pro/models/pdf_tool.dart';
import 'package:pdf_lab_pro/models/recent_file.dart';
import 'package:pdf_lab_pro/providers/file_provider.dart';
import 'package:pdf_lab_pro/providers/app_providers.dart';
import 'package:pdf_lab_pro/services/activity_tracker.dart';
import 'package:pdf_lab_pro/utils/constants.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // PDF tools: only 6 items for dashboard
  final List<PDFTool> _dashboardTools = [
    // Most commonly used tools (prioritize these)
    PDFToolsData.allTools.firstWhere((tool) => tool.id == 'merge_pdf'),
    PDFToolsData.allTools.firstWhere((tool) => tool.id == 'compress_pdf'),
    PDFToolsData.allTools.firstWhere((tool) => tool.id == 'pdf_to_image'),
    PDFToolsData.allTools.firstWhere((tool) => tool.id == 'pdf_to_word'),
    PDFToolsData.allTools.firstWhere((tool) => tool.id == 'split_pdf'),
    PDFToolsData.allTools.firstWhere((tool) => tool.id == 'view_pdf'),

    // Other tools'),


  ];

  @override
  Widget build(BuildContext context) {
    final recentFiles = ref.watch(fileProvider);
    final navIndex = ref.watch(navigationIndexProvider);
    final isDarkMode = ref.watch(themeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // App Bar
            _buildAppBar(theme),
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildWelcomeSection(),
                    const SizedBox(height: 24),
                    _buildPDFToolsGrid(theme),
                    const SizedBox(height: 24),
                    _buildRecentFiles(recentFiles, theme, isDarkMode),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(navIndex, theme),
    );
  }
  // ===================== APP BAR =====================
  Widget _buildAppBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.primaryColor,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.search, size: 22, color: theme.primaryColor),
                onPressed: () {},
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: Icon(Icons.settings, size: 22, color: theme.primaryColor),
                onPressed: () {context.push(RoutePaths.settings);},
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ===================== WELCOME SECTION =====================
  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppConstants.primaryColor,
            AppConstants.secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, User!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ready to work with your PDFs?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _openFilePicker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Open PDF File',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              size: 36,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }


  // ===================== PDF TOOLS GRID =====================
  Widget _buildPDFToolsGrid(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PDF Tools',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.push(RoutePaths.allTools);
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: _dashboardTools.length,
          itemBuilder: (context, index) {
            final tool = _dashboardTools[index];
            return _DashboardToolCard(
              tool: tool,
              theme: theme,
              onTap: () => _navigateToTool(tool),
            );
          },
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () {
              context.push(RoutePaths.allTools);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See All Tools',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppConstants.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppConstants.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===================== RECENT FILES =====================
  Widget _buildRecentFiles(List<RecentFile> recentFiles, ThemeData theme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Files',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.push(RoutePaths.files);
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (recentFiles.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? theme.colorScheme.surface
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: isDarkMode
                  ? Border.all(color: Colors.grey.shade800)
                  : null,
            ),
            child: Center(
              child: Text(
                'No recent PDF files\nOpen a PDF to get started',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
            ),
          )
        else
          Column(
            children: recentFiles.map((file) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isDarkMode
                      ? null
                      : [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      file.icon,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    file.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  subtitle: Text(
                    '${file.size} • ${file.date}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert,
                        size: 18,
                        color: theme.colorScheme.onSurface),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showFileOptions(file.path),
                  ),
                  onTap: () => _openFile(file.path),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  // ===================== BOTTOM NAV =====================
  Widget _buildBottomNavigationBar(int navIndex, ThemeData theme) {
    return BottomNavigationBar(
      backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
      type: BottomNavigationBarType.fixed,
      items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Files',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border),
            activeIcon: Icon(Icons.star),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      currentIndex: navIndex,
      selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor,
      unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor,
      showUnselectedLabels: true,

      onTap: (index) {
        ref.read(navigationIndexProvider.notifier).state = index;

        // REPLACE current logic with:
        if (index == 0) {
          // Already on dashboard, do nothing
        } else if (index == 1) {
          context.push('/files');  // Use push, not go
        } else if (index == 2) {
          context.push('/favorites');
        } else if (index == 3) {
          context.push('/profile');
        }
      },
        elevation: 0,
    );
  }


  // ===================== FILE HANDLING =====================
  Future<void> _openFilePicker() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final originalPath = result.files.single.path!;

        // Copy file to app directory and get stored path

        final appPath = await ref.read(fileProvider.notifier).addFile(originalPath);

        // Navigate to PRO PDF viewer using the stored path (owned by app)
        final encodedPath = Uri.encodeComponent(appPath);
        context.push(
          '${RoutePaths.viewPdf}?path=${Uri.encodeComponent(appPath)}',
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to open file: $e');
    }
  }

  void _openFile(String filePath) {
    final fileName = path.basename(filePath);

    ActivityTracker.logActivity(
      type: ActivityType.view,
      title: 'Viewed PDF',
      description: 'Opened $fileName',
      filePath: filePath,
    );


    context.go(
      '${RoutePaths.viewPdf}?path=${Uri.encodeComponent(filePath)}'
          '&title=${Uri.encodeComponent(fileName)}',
    );
  }



  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
      ),
    );
  }

  // ===================== TOOL NAVIGATION =====================
  void _navigateToTool(PDFTool tool) {
    switch (tool.id) {
      case 'view_pdf':
        _openFilePicker();
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
      case 'pdf_to_word':
        context.push(RoutePaths.pdfToWord);
        break;
      case 'pdf_to_excel':
        context.push(RoutePaths.pdfToExcel);
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

  // ===================== FILE OPTIONS =====================
  void _showFileOptions(String filePath) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
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
                  // TODO: Implement share
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share feature coming soon!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteFile(filePath);
                },
              ),
            ],
          ),
        );
      },
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('File deleted successfully'),
            backgroundColor: AppConstants.successColor,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete file: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }
}

// ===================== DASHBOARD TOOL CARD (GRADIENT STYLE) =====================
class _DashboardToolCard extends StatelessWidget {
  final PDFTool tool;
  final ThemeData theme;
  final VoidCallback onTap;

  const _DashboardToolCard({
    required this.tool,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashFactory: InkRipple.splashFactory,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                tool.color.withOpacity(isDarkMode ? 0.25 : 0.16),
                theme.colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: tool.color.withOpacity(isDarkMode ? 0.4 : 0.25),
              width: 0.8,
            ),
            boxShadow: [
              if (isDarkMode)
                BoxShadow(
                  color: tool.color.withOpacity(0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              else
                BoxShadow(
                  color: tool.color.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              if (!isDarkMode)
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
              // Centered icon bubble
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tool.color.withOpacity(isDarkMode ? 0.35 : 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  tool.icon,
                  color: tool.color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              // Tool title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  tool.title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
