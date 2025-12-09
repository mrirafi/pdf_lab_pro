import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_lab_pro/utils/constants.dart';

class NativePdfOpener {
  static const _channel = MethodChannel('pdf_lab_pro/open_file');

  static void init(GoRouter router) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openPdf') {
        final path = call.arguments as String?;
        if (path == null || path.isEmpty) return;

        // Navigate to your FastPDFViewer route
        final encodedPath = Uri.encodeComponent(path);
        router.go('${RoutePaths.viewPdf}?path=$encodedPath');
      }
    });
  }
}
