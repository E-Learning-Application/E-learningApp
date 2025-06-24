import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/feature/Auth/login/presentation/views/login_view.dart';
import 'package:e_learning_app/feature/settings/data/settings_cubit.dart';
import 'package:e_learning_app/feature/settings/data/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsCubit(
        authService: context.read<AuthService>(),
      )..initializeSettings(),
      child: const SettingsView(),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state is SettingsLogoutSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged out successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          Future.delayed(const Duration(), () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const LoginView(), 
              ),
              (route) => false, // Remove all previous routes
            );
          });
        } else if (state is SettingsLogoutFailure) {

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: ${state.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              return Column(
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
                    context: context,
                    title: 'Payment',
                    icon: Icons.payment,
                    onTap: () => context.read<SettingsCubit>().navigateToPayment(),
                  ),

                  _buildSettingSection(
                    context: context,
                    title: 'History',
                    icon: Icons.history,
                    onTap: () => context.read<SettingsCubit>().navigateToHistory(),
                  ),

                  // Support Section Header
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
                    child: Text(
                      'Support',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),

                  _buildSettingSection(
                    context: context,
                    title: 'Help Center',
                    icon: Icons.help_outline,
                    onTap: () => context.read<SettingsCubit>().navigateToHelpCenter(),
                  ),

                  _buildSettingSection(
                    context: context,
                    title: 'Contact us',
                    icon: Icons.mail_outline,
                    onTap: () => context.read<SettingsCubit>().navigateToContactUs(),
                    hasExternalLink: true,
                  ),

                  // Account Section Header
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
                    child: Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),

                  _buildSettingSection(
                    context: context,
                    title: 'Change password',
                    icon: Icons.lock_outline,
                    onTap: () => context.read<SettingsCubit>().navigateToChangePassword(),
                  ),

                  _buildSettingSection(
                    context: context,
                    title: 'Logout',
                    icon: Icons.exit_to_app,
                    onTap: () => _showLogoutDialog(context),
                    isLogout: true,
                    isLoading: state is SettingsLogoutLoading,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<SettingsCubit>().logout();
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool hasExternalLink = false,
    bool isLogout = false,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
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
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isLogout ? Colors.red : Colors.blue,
                        ),
                      ),
                    )
                  : Icon(
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
            if (!isLoading)
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