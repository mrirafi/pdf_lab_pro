import 'dart:ui';

class AppConstants {
  // App info
  static const String appName = 'PDF Lab Pro';
  static const String version = '1.0.0';

  // Storage paths
  static const String appDirectory = 'pdf_lab_pro';
  static const String tempDirectory = 'temp';

  // File extensions
  static const List<String> supportedExtensions = ['.pdf'];
  static const List<String> imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp'];

  // Colors
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03A9F4);
  static const Color accentColor = Color(0xFF00BCD4);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);

  // Animations
  static const Duration animationDuration = Duration(milliseconds: 300);

  // Limits
  static const int maxFileSizeMB = 50; // 50MB max file size
  static const int maxPagesForPreview = 10;
}

class RoutePaths {
  // Main screens
  static const String dashboard = '/';
  static const String allTools = '/all-tools';
  static const String settings = '/settings';
  static const String viewPdf = '/view-pdf';

  // View & Edit Tools
  static const String editPdf = '/edit-pdf';
  static const String annotatePdf = '/annotate-pdf';
  static const String signPdf = '/sign-pdf';

  // Organize Tools
  static const String mergePdf = '/merge-pdf';
  static const String splitPdf = '/split-pdf';
  static const String compressPdf = '/compress-pdf';
  static const String extractPages = '/extract-pages';
  static const String reorderPages = '/reorder-pages';

  // Convert Tools
  static const String pdfToWord = '/pdf-to-word';
  static const String pdfToExcel = '/pdf-to-excel';
  static const String pdfToPpt = '/pdf-to-ppt';
  static const String pdfToImage = '/pdf-to-image';
  static const String imageToPdf = '/image-to-pdf';
  static const String wordToPdf = '/word-to-pdf';

  // Security Tools
  static const String protectPdf = '/protect-pdf';
  static const String unlockPdf = '/unlock-pdf';
  static const String watermarkPdf = '/watermark-pdf';
  static const String redactPdf = '/redact-pdf';
  static const String digitalSign = '/digital-sign';

  // Other Tools
  static const String scanToPdf = '/scan-to-pdf';
  static const String ocrPdf = '/ocr-pdf';
  static const String repairPdf = '/repair-pdf';
  static const String comparePdf = '/compare-pdf';

  // Bottom Nav Routes
  static const String files = '/files';
  static const String favorites = '/favorites';
  static const String profile = '/profile';
  static const String allToolsNav = '/tools'; // Different from /all-tools
}

class AssetPaths {
  static const String icons = 'assets/icons/';
  static const String images = 'assets/images/';
  static const String fonts = 'assets/fonts/';
}