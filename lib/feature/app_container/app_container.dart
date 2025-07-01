import 'dart:async';
import 'package:e_learning_app/feature/Auth/data/auth_cubit.dart';
import 'package:e_learning_app/feature/Auth/data/auth_state.dart';
import 'package:e_learning_app/feature/home/presentation/views/home_view.dart';
import 'package:e_learning_app/feature/messages/presentation/views/messages_view.dart';
import 'package:e_learning_app/feature/profile/presentation/views/profile_view.dart';
import 'package:e_learning_app/feature/settings/presentation/view/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authCubit = context.read<AuthCubit>();
      final currentState = authCubit.state;

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
    if (_hasInitialized) return;

    _hasInitialized = true;
    final authCubit = context.read<AuthCubit>();

    final currentState = authCubit.state;
    if (currentState is! AuthAuthenticated && currentState is! LoginSuccess) {
      await authCubit.checkAuthStatus();
    }

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
        if (context.read<AuthCubit>().isAuthenticated) {
          _validateToken();
        }

        // Restart periodic timer if it was cancelled
        if (_tokenCheckTimer?.isActive != true) {
          _startTokenValidation();
        }
        break;
      case AppLifecycleState.paused:
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

    final authCubit = context.read<AuthCubit>();
    if (authCubit.isAuthenticated && (index == 2 || index == 3)) {
      _validateToken();
    }
  }

  void _handleAuthStateChange(AuthState state) {
    if (state is LoginSuccess) {
      context.read<AuthCubit>().setAuthenticated(state.user, state.accessToken);
      return;
    }

    if (state is AuthTokenExpired) {
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
            },
          ),
        ),
      );

      // Reset to home page
      setState(() {
        _currentIndex = 0;
      });
    } else if (state is AuthUnauthenticated) {
      setState(() {
        _currentIndex = 0;
      });
    } else if (state is AuthError) {
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
