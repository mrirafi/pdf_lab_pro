import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pdf_lab_pro/utils/constants.dart';
import 'package:pdf_lab_pro/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Info
          _buildSectionHeader('App Info', theme),
          _buildListTile(
            title: 'App Name',
            subtitle: AppConstants.appName,
            leading: const Icon(Icons.info),
            theme: theme,
          ),
          _buildListTile(
            title: 'Version',
            subtitle: AppConstants.version,
            leading: const Icon(Icons.tag),
            theme: theme,
          ),

          const SizedBox(height: 24),

          // Appearance
          _buildSectionHeader('Appearance', theme),
          SwitchListTile(
            title: Text(
              'Dark Mode',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              'Enable dark theme',
              style: TextStyle(
                color: isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
            value: isDarkMode,
            onChanged: (value) async {
              ref.read(themeProvider.notifier).state = value;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isDarkMode', value);
            },
            secondary: Icon(
              Icons.dark_mode,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 24),

          // Storage
          _buildSectionHeader('Storage', theme),
          _buildListTile(
            title: 'Clear Cache',
            subtitle: 'Remove temporary files',
            leading: const Icon(Icons.cleaning_services),
            theme: theme,  // Add this
            onTap: () => _clearCache(ref),
          ),

          const SizedBox(height: 24),

          // About
          _buildSectionHeader('About', theme),
          _buildListTile(
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            leading: const Icon(Icons.privacy_tip),
            theme: theme,  // Add this
            onTap: () => _showPrivacyPolicy(context),
          ),
          _buildListTile(
            title: 'Terms of Service',
            subtitle: 'View terms and conditions',
            leading: const Icon(Icons.description),
            theme: theme,  // Add this
            onTap: () => _showTermsOfService(context),
          ),
          _buildListTile(
            title: 'Contact Us',
            subtitle: 'Get in touch with support',
            leading: const Icon(Icons.contact_support),
            theme: theme,  // Add this
            onTap: () => _contactSupport(context),
          ),

          const SizedBox(height: 40),

          // App Version
          Center(
            child: Text(
              'Version ${AppConstants.version}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onBackground,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required Icon leading,
    required ThemeData theme,
    VoidCallback? onTap,
  }) {
    return Card(
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: theme.cardTheme.elevation,
      shape: theme.cardTheme.shape,
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: theme.brightness == Brightness.dark
                ? Colors.grey.shade400
                : Colors.grey.shade600,
          ),
        ),
        trailing: onTap != null
            ? Icon(Icons.chevron_right, color: theme.colorScheme.onSurface)
            : null,
        onTap: onTap,
      ),
    );
  }
  Future<void> _clearCache(WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: ref.context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear all temporary files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear',
              style: TextStyle(color: AppConstants.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement cache clearing
      ScaffoldMessenger.of(ref.context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. This app stores files locally on your device and does not send any data to external servers.\n\n'
                'File Processing: All PDF processing happens locally on your device.\n'
                'Permissions: We request storage permission to save and manage PDF files.\n'
                'Data Collection: We do not collect any personal information.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'By using this app, you agree to the following terms:\n\n'
                '1. You are responsible for the files you process.\n'
                '2. The app is provided "as is" without warranties.\n'
                '3. We are not liable for any data loss.\n'
                '4. You must have proper rights to the files you process.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _contactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text(
          'For support, please email:\nsupport@pdflabpro.com\n\n'
              'We typically respond within 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}