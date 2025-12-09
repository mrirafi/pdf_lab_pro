// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_lab_pro/app/app.dart';
import 'package:pdf_lab_pro/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme preference BEFORE ProviderScope
  final prefs = await SharedPreferences.getInstance();
  initialDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(const ProviderScope(child: MyApp()));
}
