import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_lab_pro/utils/constants.dart';
import 'package:pdf_lab_pro/providers/app_providers.dart';
import 'package:pdf_lab_pro/services/file_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final FileService _fileService = FileService();
  Map<String, dynamic> _storageStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stats = await _fileService.getStorageStats() as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _storageStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar

          SliverAppBar(
            backgroundColor: theme.appBarTheme.backgroundColor,
            foregroundColor: theme.appBarTheme.foregroundColor,
            elevation: 0,
            pinned: true,
            title: Text(
              'Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User Info Card
                  _buildUserInfoCard(theme),
                  const SizedBox(height: 20),

                  // Storage Stats
                  _buildStorageCard(theme),
                  const SizedBox(height: 20),

                  // App Settings
                  _buildSettingsCard(theme),
                  const SizedBox(height: 20),

                  // Support & About
                  _buildSupportCard(theme),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppConstants.primaryColor,
                    AppConstants.secondaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // User Name
            Text(
              'PDF User',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            // Email
            Text(
              'user@example.com',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),

            // Member Since
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Member since ${DateTime.now().year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Storage Usage',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (_storageStats.isNotEmpty)
                  Text(
                    _storageStats['totalSizeFormatted'] ?? '0 B',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const LinearProgressIndicator()
            else if (_storageStats.isNotEmpty)
              Column(
                children: [
                  // Storage Progress
                  LinearProgressIndicator(
                    value: _calculateStoragePercentage(),
                    backgroundColor: theme.dividerColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getStorageColor(_calculateStoragePercentage()),
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),

                  // Storage Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'App Files',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          Text(
                            _storageStats['appDirectorySizeFormatted'] ?? '0 B',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Temporary',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          Text(
                            _storageStats['tempDirectorySizeFormatted'] ?? '0 B',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Clear Cache Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _clearCache,
                      icon: const Icon(Icons.cleaning_services),
                      label: const Text('Clear Temporary Files'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: BorderSide(color: Colors.orange.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                'Unable to load storage information',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(ThemeData theme) {
    final isDarkMode = ref.watch(themeProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Theme Toggle
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: theme.primaryColor,
                ),
              ),
              title: Text(
                'Dark Mode',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                isDarkMode ? 'Enabled' : 'Disabled',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              trailing: Switch(
                value: isDarkMode,
                onChanged: (value) async {
                  ref.read(themeProvider.notifier).state = value;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isDarkMode', value);
                },
                activeColor: theme.primaryColor,
              ),
              onTap: () async {
                final newValue = !isDarkMode;
                ref.read(themeProvider.notifier).state = newValue;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isDarkMode', newValue);
              },
            ),

            const Divider(height: 20),

            // App Version
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info,
                  color: Colors.blue,
                ),
              ),
              title: Text(
                'App Version',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Version ${AppConstants.version}',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              onTap: () => _showAppInfoDialog(),
            ),

            const Divider(height: 20),

            // Settings Button
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings,
                  color: Colors.grey,
                ),
              ),
              title: Text(
                'More Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Advanced preferences',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              onTap: () => context.push(RoutePaths.settings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Support & About',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Share App
            _buildSupportButton(
              'Share App',
              Icons.share,
              Colors.green,
              _shareApp,
              theme,
            ),

            const Divider(height: 12),

            // Rate App
            _buildSupportButton(
              'Rate App',
              Icons.star,
              Colors.amber,
              _rateApp,
              theme,
            ),

            const Divider(height: 12),

            // Contact Support
            _buildSupportButton(
              'Contact Support',
              Icons.help_outline,
              Colors.blue,
              _contactSupport,
              theme,
            ),

            const Divider(height: 12),

            // Privacy Policy
            _buildSupportButton(
              'Privacy Policy',
              Icons.privacy_tip,
              Colors.purple,
              _showPrivacyPolicy,
              theme,
            ),

            const Divider(height: 12),

            // Terms of Service
            _buildSupportButton(
              'Terms of Service',
              Icons.description,
              Colors.orange,
              _showTermsOfService,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportButton(
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ThemeData theme,
      ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurface.withOpacity(0.4),
        size: 20,
      ),
      onTap: onTap,
    );
  }

  // Helper Methods
  double _calculateStoragePercentage() {
    if (_storageStats.isEmpty) return 0;
    final totalSize = _storageStats['totalSize'] as int? ?? 0;
    if (totalSize <= 0) return 0;

    // Assuming 100MB max storage for percentage calculation
    const maxStorage = 100 * 1024 * 1024; // 100MB in bytes
    return (totalSize / maxStorage).clamp(0.0, 1.0);
  }

  Color _getStorageColor(double percentage) {
    if (percentage < 0.5) return Colors.green;
    if (percentage < 0.8) return Colors.orange;
    return Colors.red;
  }

  // Action Methods
  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Temporary Files'),
        content: const Text('This will remove all temporary files. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _fileService.clearTempDirectory();
        await _loadData(); // Refresh stats

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Temporary files cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareApp() async {
    try {
      final text = 'Check out PDF Lab Pro - All-in-one PDF Tools App!\n\n'
          'Download now and enjoy powerful PDF editing features.';

      await Share.share(
        text,
        subject: 'PDF Lab Pro - PDF Tools App',
      );
    } catch (e) {
      _showError('Failed to share app');
    }
  }

  Future<void> _rateApp() async {
    try {
      final url = Platform.isAndroid
          ? Uri.parse('market://details?id=com.meghpy.pdf_lab_pro')
          : Uri.parse('https://apps.apple.com/app/idYOUR_APP_ID');

      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showError('Unable to open app store');
      }
    } catch (e) {
      _showError('Failed to open rating page');
    }
  }

  Future<void> _contactSupport() async {
    try {
      final email = Uri(
        scheme: 'mailto',
        path: 'support@pdflabpro.com',
        queryParameters: {
          'subject': 'PDF Lab Pro Support Request',
          'body': 'Please describe your issue or question:\n\n',
        },
      );

      if (await canLaunchUrl(email)) {
        await launchUrl(email);
      } else {
        _showError('Unable to open email client');
      }
    } catch (e) {
      _showError('Failed to contact support');
    }
  }

  void _showAppInfoDialog() {
    final now = DateTime.now();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('App Name', AppConstants.appName),
            _infoRow('Version', AppConstants.version),
            _infoRow('Developer', 'PDF Lab Pro Team'),
            const SizedBox(height: 12),
            Text(
              'All-in-one PDF tools for your mobile device. '
                  'Process PDFs quickly and efficiently.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              'Last updated: ${now.year}-${now.month}-${now.day}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    final now = DateTime.now();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Privacy Policy for PDF Lab Pro\n\n',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text: '1. Data Collection:\n'
                      '   - We do not collect any personal information\n'
                      '   - All PDF processing happens locally on your device\n'
                      '   - No data is sent to external servers\n\n'
                      '2. File Storage:\n'
                      '   - Files are stored locally in your device\'s storage\n'
                      '   - You have full control over your files\n'
                      '   - We never access your files without your permission\n\n'
                      '3. Permissions:\n'
                      '   - Storage permission is required to save and manage PDF files\n'
                      '   - Photos permission is required to save converted images\n'
                      '   - Permissions are used only for app functionality\n\n'
                      '4. Third-Party Services:\n'
                      '   - No third-party analytics or tracking\n'
                      '   - No advertisements in the app\n\n',
                ),
                TextSpan(
                  text: 'Last updated: ${now.year}-${now.month}-${now.day}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
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

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'Terms of Service for PDF Lab Pro\n\n'
                '1. Acceptance of Terms:\n'
                '   By using PDF Lab Pro, you agree to these terms.\n\n'
                '2. App Usage:\n'
                '   - You are responsible for the files you process\n'
                '   - The app is for personal and legitimate business use\n'
                '   - Do not use for illegal or unauthorized purposes\n\n'
                '3. Disclaimer:\n'
                '   - The app is provided "as is" without warranties\n'
                '   - We are not liable for any data loss or damage\n'
                '   - Use at your own risk\n\n'
                '4. Intellectual Property:\n'
                '   - All app content is owned by PDF Lab Pro\n'
                '   - Do not reverse engineer or copy the app\n\n'
                '5. Changes to Terms:\n'
                '   We may update these terms at any time.\n\n'
                'For questions: support@pdflabpro.com',
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}