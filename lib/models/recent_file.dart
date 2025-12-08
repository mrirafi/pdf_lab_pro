import 'package:flutter/material.dart';

class RecentFile {
  final String path;
  final String name;
  final String size;
  final String date;
  final IconData icon;

  RecentFile({
    required this.path,
    required this.name,
    required this.size,
    required this.date,
    required this.icon,
  });
}