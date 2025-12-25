import 'package:go_router/go_router.dart';
import 'package:pdf_lab_pro/screens/dashboard_screen.dart';
import 'package:pdf_lab_pro/screens/all_tools_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/favorites_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/pdf_merge_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/profile_screen.dart';
import 'package:pdf_lab_pro/screens/settings_screen.dart';


// View & Edit Tools
import 'package:pdf_lab_pro/screens/pdf_tools/edit_pdf_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/annotate_pdf_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/sign_pdf_screen.dart';

// Organize Tools
import 'package:pdf_lab_pro/screens/pdf_tools/split_pdf_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/compress_pdf_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/extract_pages_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/reorder_pages_screen.dart';


// Convert Tools
import 'package:pdf_lab_pro/screens/pdf_tools/pdf_to_word_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/pdf_to_excel_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/pdf_to_ppt_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/pdf_to_image_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/image_to_pdf_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/word_to_pdf_screen.dart';

// Security Tools
import 'package:pdf_lab_pro/screens/pdf_tools/protect_pdf_screen.dart';
import 'package:pdf_lab_pro/screens/pdf_tools/watermark_pdf_screen.dart';

import 'package:pdf_lab_pro/utils/constants.dart';

import '../screens/pdf_tools/files_screen.dart';
import '../screens/viewer/fast_pdf_viewer.dart';


final goRouter = GoRouter(
  initialLocation: RoutePaths.dashboard,
  routes: [

    // New bottom navigation routes
    GoRoute(
      path: '/files',
      name: 'files',
      builder: (context, state) => const FilesScreen(),
    ),

    GoRoute(
      path: '/favorites',
      name: 'favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),

    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    // Dashboard - Home Screen
    GoRoute(
      path: RoutePaths.dashboard,
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),

    // All Tools Screen
    GoRoute(
      path: RoutePaths.allTools,
      name: 'all_tools',
      builder: (context, state) => const AllToolsScreen(),
    ),

    // Settings
    GoRoute(
      path: RoutePaths.settings,
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    // PDF Viewer
    GoRoute(
      path: RoutePaths.viewPdf,
      name: 'view_pdf',
      builder: (context, state) {
        final filePath = state.uri.queryParameters['path'] ?? '';
        final title = state.uri.queryParameters['title'];
        final pageParam = state.uri.queryParameters['page'];
        final initialPage = pageParam != null ? int.tryParse(pageParam) : null;

        return FastPDFViewer(
          filePath: filePath,
          title: title,
          initialPage: initialPage, // Pass the page parameter
        );
      },
    ),
    // ============ VIEW & EDIT TOOLS ============
    GoRoute(
      path: RoutePaths.editPdf,
      name: 'edit_pdf',
      builder: (context, state) => const EditPdfScreen(),
    ),
    GoRoute(
      path: RoutePaths.annotatePdf,
      name: 'annotate_pdf',
      builder: (context, state) => const AnnotatePdfScreen(),
    ),
    GoRoute(
      path: RoutePaths.signPdf,
      name: 'sign_pdf',
      builder: (context, state) => const SignPdfScreen(),
    ),

    // ============ ORGANIZE TOOLS ============
    GoRoute(
      path: RoutePaths.mergePdf,
      name: 'merge_pdf',
      builder: (context, state) => const PdfMergeScreen(),
    ),
    GoRoute(
      path: RoutePaths.splitPdf,
      name: 'split_pdf',
      builder: (context, state) => const SplitPdfScreen(),
    ),
    GoRoute(
      path: RoutePaths.compressPdf,
      name: 'compress_pdf',
      builder: (context, state) => const CompressPdfScreen(),
    ),
    GoRoute(
      path: RoutePaths.extractPages,
      name: 'extract_pages',
      builder: (context, state) => const ExtractPagesScreen(),
    ),
    GoRoute(
      path: RoutePaths.reorderPages,
      name: 'reorder_pages',
      builder: (context, state) => const ReorderPagesScreen(),
    ),


    // ============ CONVERT TOOLS ============
    GoRoute(
      path: RoutePaths.pdfToWord,
      name: 'pdf_to_word',
      builder: (context, state) => const PdfToWordScreen(),
    ),
    GoRoute(
      path: RoutePaths.pdfToExcel,
      name: 'pdf_to_excel',
      builder: (context, state) => const PdfToExcelScreen(),
    ),
    GoRoute(
      path: RoutePaths.pdfToPpt,
      name: 'pdf_to_ppt',
      builder: (context, state) => const PdfToPptScreen(),
    ),
    GoRoute(
      path: RoutePaths.pdfToImage,
      name: 'pdf_to_image',
      builder: (context, state) => const PdfToImageScreen(),
    ),
    GoRoute(
      path: RoutePaths.imageToPdf,
      name: 'image_to_pdf',
      builder: (context, state) => const ImageToPdfScreen(),
    ),
    GoRoute(
      path: RoutePaths.wordToPdf,
      name: 'word_to_pdf',
      builder: (context, state) => const WordToPdfScreen(),
    ),

    // ============ SECURITY TOOLS ============
    GoRoute(
      path: RoutePaths.protectPdf,
      name: 'protect_pdf',
      builder: (context, state) => const ProtectPdfScreen(),
    ),
    GoRoute(
      path: RoutePaths.watermarkPdf,
      name: 'watermark_pdf',
      builder: (context, state) => const WatermarkPdfScreen(),
    ),
  ],
);