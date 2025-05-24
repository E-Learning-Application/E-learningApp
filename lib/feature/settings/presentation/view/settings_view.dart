import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Bar
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Settings List
            _buildSettingSection(
              title: 'Payment',
              icon: Icons.payment,
              onTap: () {},
            ),

            _buildSettingSection(
              title: 'History',
              icon: Icons.history,
              onTap: () {},
            ),

            // Support Section Header
            Padding(
              padding:
                  const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
              child: Text(
                'Support',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),

            _buildSettingSection(
              title: 'Help Center',
              icon: Icons.help_outline,
              onTap: () {},
            ),

            _buildSettingSection(
              title: 'Contact us',
              icon: Icons.mail_outline,
              onTap: () {},
              hasExternalLink: true,
            ),

            // Account Section Header
            Padding(
              padding:
                  const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
              child: Text(
                'Account',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),

            _buildSettingSection(
              title: 'Change password',
              icon: Icons.lock_outline,
              onTap: () {},
            ),

            _buildSettingSection(
              title: 'Logout',
              icon: Icons.exit_to_app,
              onTap: () {},
              isLogout: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSection({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool hasExternalLink = false,
    bool isLogout = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isLogout ? Colors.red[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isLogout ? Colors.red : Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            // Title
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isLogout ? Colors.red : Colors.black87,
                ),
              ),
            ),
            // Arrow or external link icon
            Icon(
              hasExternalLink ? Icons.open_in_new : Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
