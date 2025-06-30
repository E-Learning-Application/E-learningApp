import 'package:e_learning_app/feature/Auth/data/auth_cubit.dart';
import 'package:e_learning_app/feature/Auth/data/auth_state.dart';
import 'package:e_learning_app/feature/language/presentation/view/language_view.dart';
import 'package:e_learning_app/feature/messages/presentation/views/messages_view.dart';
import 'package:e_learning_app/feature/profile/presentation/views/profile_view.dart';
import 'package:e_learning_app/feature/settings/presentation/view/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

class AppContainer extends StatefulWidget {
  const AppContainer({super.key});

  @override
  State<AppContainer> createState() => _AppContainerState();
}

class _AppContainerState extends State<AppContainer>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _tokenCheckTimer;
  bool _isCheckingToken = false;
  bool _hasInitialized = false; // Add this flag

  final List<Widget> _pages = [
    const HomeScreen(),
    const MessagesScreen(),
    const SettingsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Only check auth status if we haven't initialized and user isn't already authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authCubit = context.read<AuthCubit>();
      final currentState = authCubit.state;

      // If user is already authenticated (coming from login), just start validation
      if (currentState is AuthAuthenticated || currentState is LoginSuccess) {
        _hasInitialized = true;
        _startTokenValidation();
      } else if (!_hasInitialized) {
        _initialAuthCheck();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialAuthCheck() async {
    if (_hasInitialized) return; // Prevent multiple initialization

    _hasInitialized = true;
    final authCubit = context.read<AuthCubit>();

    // Only check auth status if user is not already authenticated
    final currentState = authCubit.state;
    if (currentState is! AuthAuthenticated && currentState is! LoginSuccess) {
      await authCubit.checkAuthStatus();
    }

    // Start periodic validation
    _startTokenValidation();
  }

  void _startTokenValidation() {
    _tokenCheckTimer?.cancel(); // Cancel any existing timer
    _tokenCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && !_isCheckingToken) {
        _validateToken();
      }
    });
  }

  Future<void> _validateToken() async {
    if (_isCheckingToken) return;

    setState(() {
      _isCheckingToken = true;
    });

    try {
      final authCubit = context.read<AuthCubit>();

      if (authCubit.isAuthenticated) {
        await authCubit.validateAndRefreshToken();
      }
    } catch (e) {
      print('Error during token validation: $e');
      // Don't show error to user for background validation
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground - validate token
        if (context.read<AuthCubit>().isAuthenticated) {
          _validateToken();
        }

        // Restart periodic timer if it was cancelled
        if (_tokenCheckTimer?.isActive != true) {
          _startTokenValidation();
        }
        break;
      case AppLifecycleState.paused:
        // App going to background - pause timer to save resources
        _tokenCheckTimer?.cancel();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Optional: Validate token when switching to sensitive pages
    final authCubit = context.read<AuthCubit>();
    if (authCubit.isAuthenticated && (index == 2 || index == 3)) {
      // Settings or Profile
      _validateToken();
    }
  }

  void _handleAuthStateChange(AuthState state) {
    // Handle LoginSuccess by converting to AuthAuthenticated
    if (state is LoginSuccess) {
      // Don't show snackbar here as it's already handled in LoginView
      // Just ensure the user state is properly set
      context.read<AuthCubit>().setAuthenticated(state.user, state.accessToken);
      return;
    }

    if (state is AuthTokenExpired) {
      // Token expired - show snackbar and redirect to login
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message ?? 'Session expired'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Login',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to login page
              // Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ),
      );

      // Reset to home page
      setState(() {
        _currentIndex = 0;
      });
    } else if (state is AuthUnauthenticated) {
      // User logged out or session ended
      setState(() {
        _currentIndex = 0;
      });
    } else if (state is AuthError) {
      // Show error message only if it's not a background validation error
      if (!_isCheckingToken) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) => _handleAuthStateChange(state),
      child: Scaffold(
        body: Stack(
          children: [
            _pages[_currentIndex],
            if (_isCheckingToken)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Syncing...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onPageChanged,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined), label: ''),
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline), label: ''),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined), label: ''),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline), label: ''),
            ],
            showSelectedLabels: false,
            showUnselectedLabels: false,
          ),
        ),
      ),
    );
  }
}

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
