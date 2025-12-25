import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_lab_pro/app/app.dart';
import 'package:pdf_lab_pro/app/router.dart';
import 'package:pdf_lab_pro/services/native_pdf_opener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize listener for "Open with PDF" from Android
  NativePdfOpener.init(goRouter);

  runApp(const ProviderScope(child: MyApp()));
}
