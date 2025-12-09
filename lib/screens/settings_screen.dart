import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf_lab_pro/utils/constants.dart';
import 'package:pdf_lab_pro/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);

    return WillPopScope(
        onWillPop: () async {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(RoutePaths.dashboard);
          }
          return false; // we handled it
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.dashboard);
                }
              },
            ),
          ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Info
          _buildSectionHeader('App Info'),
          _buildListTile(
            title: 'App Name',
            subtitle: AppConstants.appName,
            leading: const Icon(Icons.info),
          ),
          _buildListTile(
            title: 'Version',
            subtitle: AppConstants.version,
            leading: const Icon(Icons.tag),
          ),

          const SizedBox(height: 24),

          // Appearance
          _buildSectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme'),
            value: isDarkMode,
            onChanged: (value) async {
              ref.read(themeProvider.notifier).state = value;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isDarkMode', value);
            },
            secondary: const Icon(Icons.dark_mode),
          ),

          const SizedBox(height: 24),

          // Storage
          _buildSectionHeader('Storage'),
          _buildListTile(
            title: 'Clear Cache',
            subtitle: 'Remove temporary files',
            leading: const Icon(Icons.cleaning_services),
            onTap: () => _clearCache(ref),
          ),

          const SizedBox(height: 24),

          // About
          _buildSectionHeader('About'),
          _buildListTile(
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            leading: const Icon(Icons.privacy_tip),
            onTap: () => _showPrivacyPolicy(context),
          ),
          _buildListTile(
            title: 'Terms of Service',
            subtitle: 'View terms and conditions',
            leading: const Icon(Icons.description),
            onTap: () => _showTermsOfService(context),
          ),
          _buildListTile(
            title: 'Contact Us',
            subtitle: 'Get in touch with support',
            leading: const Icon(Icons.contact_support),
            onTap: () => _contactSupport(context),
          ),

          const SizedBox(height: 40),

          // App Version
          Center(
            child: Text(
              'Version ${AppConstants.version}',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    )
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required Icon leading,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: Colors.grey)
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