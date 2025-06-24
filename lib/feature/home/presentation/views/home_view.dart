import 'package:e_learning_app/feature/home/data/home_cubit.dart';
import 'package:e_learning_app/feature/home/data/home_state.dart';
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
    _startTokenValidation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateToken();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenCheckTimer?.cancel();
    super.dispose();
  }

  void _startTokenValidation() {
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
        _validateToken();
        
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
    // Validate token before changing page
    if (context.read<AuthCubit>().isAuthenticated) {
      _validateToken();
    }
    
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthTokenExpired) {
          // Token expired - show snackbar and redirect to login
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          
          setState(() {
            _currentIndex = 0;
          });
          
          
        } else if (state is AuthUnauthenticated) {
          setState(() {
            _currentIndex = 0;
          });
        } else if (state is AuthError) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            _pages[_currentIndex],
            
            if (_isCheckingToken)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  bool isAuthenticated = true;

                  if (state is AuthAuthenticated) {
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
                          if (state is AuthLoading)
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
                        onTap: () {
                          if (isAuthenticated) {
                            context.read<AuthCubit>().validateAndRefreshToken();
                            Navigator.push(context, MaterialPageRoute(builder: (context) => LanguageSelectionPage(),));
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isAuthenticated ? Colors.grey[800] : Colors.grey[400],
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
        const SnackBar(
          content: Text('Please login to access this feature'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate token before accessing features
    await authCubit.validateAndRefreshToken();
    
    // Check state after validation
    final currentState = authCubit.state;
    if (currentState is AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$feature feature accessed'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please login again.'),
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
            ],
          ),
        ),
      ),
    );
  }
}