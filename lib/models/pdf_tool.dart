import 'package:flutter/material.dart';
import 'package:pdf_lab_pro/utils/constants.dart';

class PDFTool {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final String category;
  final String description;
  final String route; // Always from RoutePaths now

  PDFTool({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.category,
    required this.description,
    required this.route,
  });
}

class PDFToolsData {
  static final List<PDFTool> allTools = [
    // View & Edit Tools
    PDFTool(
      id: 'view_pdf',
      title: 'View PDF',
      icon: Icons.picture_as_pdf,
      color: Colors.blue,
      category: 'View & Edit',
      description: 'Open and view PDF files',
      route: RoutePaths.viewPdf,
    ),
    PDFTool(
      id: 'edit_pdf',
      title: 'Edit PDF',
      icon: Icons.edit,
      color: Colors.blueAccent,
      category: 'View & Edit',
      description: 'Edit text and images in PDF',
      route: RoutePaths.editPdf,
    ),
    PDFTool(
      id: 'annotate',
      title: 'Annotate',
      icon: Icons.draw,
      color: Colors.lightBlue,
      category: 'View & Edit',
      description: 'Add annotations and comments',
      route: RoutePaths.annotatePdf,
    ),
    PDFTool(
      id: 'sign_pdf',
      title: 'Sign PDF',
      icon: Icons.edit_note, // Changed from signature
      color: Colors.cyan,
      category: 'View & Edit',
      description: 'Add digital signatures',
      route: RoutePaths.signPdf,
    ),

    // Convert Tools
    PDFTool(
      id: 'pdf_to_word',
      title: 'PDF to Word',
      icon: Icons.description,
      color: Colors.green,
      category: 'Convert',
      description: 'Convert PDF to Word document',
      route: RoutePaths.pdfToWord,
    ),
    PDFTool(
      id: 'pdf_to_excel',
      title: 'PDF to Excel',
      icon: Icons.table_chart,
      color: Colors.lightGreen,
      category: 'Convert',
      description: 'Convert PDF to Excel spreadsheet',
      route: RoutePaths.pdfToExcel,
    ),
    PDFTool(
      id: 'pdf_to_ppt',
      title: 'PDF to PPT',
      icon: Icons.slideshow,
      color: Colors.teal,
      category: 'Convert',
      description: 'Convert PDF to PowerPoint',
      route: RoutePaths.pdfToPpt,
    ),
    PDFTool(
      id: 'pdf_to_image',
      title: 'PDF to Image',
      icon: Icons.image,
      color: Colors.greenAccent,
      category: 'Convert',
      description: 'Convert PDF pages to images',
      route: RoutePaths.pdfToImage,
    ),
    PDFTool(
      id: 'image_to_pdf',
      title: 'Image to PDF',
      icon: Icons.image_aspect_ratio,
      color: Colors.tealAccent,
      category: 'Convert',
      description: 'Convert images to PDF',
      route: RoutePaths.imageToPdf,
    ),
    PDFTool(
      id: 'word_to_pdf',
      title: 'Word to PDF',
      icon: Icons.file_present,
      color: Colors.green,
      category: 'Convert',
      description: 'Convert Word to PDF',
      route: RoutePaths.wordToPdf,
    ),

    // Organize Tools
    PDFTool(
      id: 'merge_pdf',
      title: 'Merge PDF',
      icon: Icons.merge,
      color: Colors.orange,
      category: 'Organize',
      description: 'Combine multiple PDFs',
      route: RoutePaths.mergePdf,
    ),
    PDFTool(
      id: 'split_pdf',
      title: 'Split PDF',
      icon: Icons.call_split,
      color: Colors.deepOrange,
      category: 'Organize',
      description: 'Split PDF into multiple files',
      route: RoutePaths.splitPdf,
    ),
    PDFTool(
      id: 'compress_pdf',
      title: 'Compress PDF',
      icon: Icons.compress,
      color: Colors.amber,
      category: 'Organize',
      description: 'Reduce PDF file size',
      route: RoutePaths.compressPdf,
    ),
    PDFTool(
      id: 'extract_pages',
      title: 'Extract Pages',
      icon: Icons.content_cut,
      color: Colors.orangeAccent,
      category: 'Organize',
      description: 'Extract specific pages',
      route: RoutePaths.extractPages,
    ),
    PDFTool(
      id: 'reorder_pages',
      title: 'Reorder Pages',
      icon: Icons.reorder,
      color: Colors.amber,
      category: 'Organize',
      description: 'Rearrange PDF pages',
      route: RoutePaths.reorderPages,
    ),

    // Security Tools
    PDFTool(
      id: 'protect_pdf',
      title: 'Protect PDF',
      icon: Icons.lock,
      color: Colors.red,
      category: 'Security',
      description: 'Add password protection',
      route: RoutePaths.protectPdf,
    ),
    // PDFTool(
    //   id: 'unlock_pdf',
    //   title: 'Unlock PDF',
    //   icon: Icons.lock_open,
    //   color: Colors.redAccent,
    //   category: 'Security',
    //   description: 'Remove password protection',
    //   route: RoutePaths.unlockPdf,
    // ),
    PDFTool(
      id: 'watermark',
      title: 'Watermark',
      icon: Icons.water_damage,
      color: Colors.pink,
      category: 'Security',
      description: 'Add watermark to PDF',
      route: RoutePaths.watermarkPdf,
    ),
    // PDFTool(
    //   id: 'redact_pdf',
    //   title: 'Redact PDF',
    //   icon: Icons.security,
    //   color: Colors.red,
    //   category: 'Security',
    //   description: 'Redact sensitive information',
    //   route: RoutePaths.redactPdf,
    // ),
    // PDFTool(
    //   id: 'digital_sign',
    //   title: 'Digital Sign',
    //   icon: Icons.verified,
    //   color: Colors.pinkAccent,
    //   category: 'Security',
    //   description: 'Add digital signature',
    //   route: RoutePaths.digitalSign,
    // ),

    // Additional Tools
    // PDFTool(
    //   id: 'scan_to_pdf',
    //   title: 'Scan to PDF',
    //   icon: Icons.scanner,
    //   color: Colors.purple,
    //   category: 'Other',
    //   description: 'Scan documents to PDF',
    //   route: RoutePaths.scanToPdf,
    // ),
    // PDFTool(
    //   id: 'ocr_pdf',
    //   title: 'OCR PDF',
    //   icon: Icons.text_fields,
    //   color: Colors.deepPurple,
    //   category: 'Other',
    //   description: 'Extract text from scanned PDF',
    //   route: RoutePaths.ocrPdf,
    // ),
    // PDFTool(
    //   id: 'repair_pdf',
    //   title: 'Repair PDF',
    //   icon: Icons.build,
    //   color: Colors.indigo,
    //   category: 'Other',
    //   description: 'Repair corrupted PDF files',
    //   route: RoutePaths.repairPdf,
    // ),
    // PDFTool(
    //   id: 'compare_pdf',
    //   title: 'Compare PDF',
    //   icon: Icons.compare,
    //   color: Colors.deepPurpleAccent,
    //   category: 'Other',
    //   description: 'Compare two PDF files',
    //   route: RoutePaths.comparePdf,
    // ),
  ];

  static List<PDFTool> getToolsByCategory(String category) {
    return allTools.where((tool) => tool.category == category).toList();
  }

  static List<String> get categories {
    return ['View & Edit', 'Convert', 'Organize', 'Security', 'Other'];
  }
}
