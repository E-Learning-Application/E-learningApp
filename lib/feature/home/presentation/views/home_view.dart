import 'package:e_learning_app/feature/Auth/data/auth_cubit.dart';
import 'package:e_learning_app/feature/Auth/data/auth_state.dart';
import 'package:e_learning_app/feature/language/presentation/view/language_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  String userName = 'User';
                  bool isAuthenticated = false;

                  // Handle both AuthAuthenticated and LoginSuccess states
                  if (state is AuthAuthenticated) {
                    userName = state.user.username;
                    isAuthenticated = true;
                  } else if (state is LoginSuccess) {
                    userName = state.user.username;
                    isAuthenticated = true;
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAuthenticated ? 'Welcome back' : 'Welcome',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                          if (state is AuthLoading || state is LoginLoading)
                            const Text(
                              'Syncing...',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (isAuthenticated) {
                            // Validate token before navigation
                            await context
                                .read<AuthCubit>()
                                .validateAndRefreshToken();

                            if (mounted &&
                                context.read<AuthCubit>().isAuthenticated) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LanguageSelectionPage(),
                                ),
                              );
                            }
                          } else {
                            // Navigate to login if not authenticated
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please login to access language settings'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isAuthenticated
                                ? Colors.grey[800]
                                : Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.language,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
              // Video Call Button
              _buildCallOption(
                title: 'Video Call',
                color: Colors.indigo,
                icon: Icons.videocam_rounded,
                onTap: () => _handleFeatureAccess(context, 'Video Call'),
              ),
              const SizedBox(height: 16),
              // Voice Call Button
              _buildCallOption(
                title: 'Voice Call',
                color: Colors.red[700]!,
                icon: Icons.mic_rounded,
                onTap: () => _handleFeatureAccess(context, 'Voice Call'),
              ),
              const SizedBox(height: 16),
              // Chat Button
              _buildCallOption(
                title: 'Only Chat',
                color: Colors.teal,
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () => _handleFeatureAccess(context, 'Chat'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _handleFeatureAccess(BuildContext context, String feature) async {
    final authCubit = context.read<AuthCubit>();

    // Check if user is authenticated
    if (!authCubit.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please login to access this feature'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Login',
            onPressed: () {
              // Navigate to login page
              // Navigator.pushNamed(context, '/login');
            },
          ),
        ),
      );
      return;
    }

    // Show loading state
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accessing $feature...'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.blue,
      ),
    );

    try {
      // Validate token before accessing features
      await authCubit.validateAndRefreshToken();

      // Check state after validation
      if (!mounted) return;

      final currentState = authCubit.state;
      if (currentState is AuthAuthenticated) {
        // Hide loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Show success and navigate to feature
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$feature ready!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // TODO: Navigate to actual feature page
        // Navigator.pushNamed(context, '/${feature.toLowerCase().replaceAll(' ', '_')}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to access $feature. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCallOption({
    required String title,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 20),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
