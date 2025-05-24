import 'package:e_learning_app/feature/home/data/home_cubit.dart';
import 'package:e_learning_app/feature/home/data/home_state.dart';
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      context.read<AuthCubit>().validateAndRefreshToken();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthTokenExpired || state is AuthUnauthenticated) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: _pages[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
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

                  if (state is AuthAuthenticated) {
                    userName = state.user.username;
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back',
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
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          // Validate token when user taps profile
                          context.read<AuthCubit>().validateAndRefreshToken();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.amber[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person,
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

  void _handleFeatureAccess(BuildContext context, String feature) {
    // Check token validity before accessing features
    context.read<AuthCubit>().validateAndRefreshToken();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature accessed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
