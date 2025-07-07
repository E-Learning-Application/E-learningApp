import 'package:e_learning_app/core/model/match_response.dart';
import 'package:e_learning_app/core/service/matching_service.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/feature/Auth/data/auth_cubit.dart';
import 'package:e_learning_app/feature/Auth/data/auth_state.dart';
import 'package:e_learning_app/feature/language/presentation/view/language_view.dart';
import 'package:e_learning_app/feature/messages/presentation/views/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MatchingService _matchingService;
  bool _isSearchingForMatch = false;
  String _currentSearchType = '';

  @override
  void initState() {
    super.initState();
    _matchingService = MatchingService(
      dioConsumer: context.read<DioConsumer>(),
      authService: context.read<AuthService>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 10),
                if (_isSearchingForMatch) _buildSearchingIndicator(),
                const SizedBox(height: 20),
                _buildFeatureOptions(),
                const SizedBox(height: 30),
                _buildActiveMatchesSection(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        String userName = 'User';
        bool isAuthenticated = false;

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
              onTap: () => _handleLanguageSettings(context, isAuthenticated),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isAuthenticated ? Colors.grey[800] : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
                child: const Center(
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
    );
  }

  Widget _buildSearchingIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Searching for $_currentSearchType match...',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _cancelSearch,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Start a conversation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Video Call Button
        _buildCallOption(
          title: 'Video Call',
          subtitle: 'Face-to-face conversation',
          color: Colors.indigo,
          icon: Icons.videocam_rounded,
          onTap: () => _handleFeatureAccess(context, 'video'),
          isLoading: _isSearchingForMatch && _currentSearchType == 'video',
        ),
        const SizedBox(height: 16),
        // Voice Call Button
        _buildCallOption(
          title: 'Voice Call',
          subtitle: 'Voice-only conversation',
          color: Colors.red[700]!,
          icon: Icons.mic_rounded,
          onTap: () => _handleFeatureAccess(context, 'voice'),
          isLoading: _isSearchingForMatch && _currentSearchType == 'voice',
        ),
        const SizedBox(height: 16),
        // Chat Button
        _buildCallOption(
          title: 'Text Chat',
          subtitle: 'Message-based conversation',
          color: Colors.teal,
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () => _handleFeatureAccess(context, 'text'),
          isLoading: _isSearchingForMatch && _currentSearchType == 'text',
        ),
      ],
    );
  }

  Widget _buildActiveMatchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Matches',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            if (state is! AuthAuthenticated && state is! LoginSuccess) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.login,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please login to view matches',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return FutureBuilder<List<MatchResponse>>(
              future: _getActiveMatches(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Error loading matches',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final matches = snapshot.data ?? [];

                if (matches.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No active matches',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    return _buildMatchCard(match);
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMatchCard(MatchResponse match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: match.matchedUser.profilePicture != null
              ? NetworkImage(match.matchedUser.profilePicture!)
              : null,
          child: match.matchedUser.profilePicture == null
              ? Text(match.matchedUser.username[0].toUpperCase())
              : null,
        ),
        title: Text(match.matchedUser.username),
        subtitle: Text(
          '${match.matchType.toUpperCase()} • ${_getTimeAgo(match.createdAt)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () => _resumeMatch(match),
            ),
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: () => _endMatch(match),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallOption({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: isLoading ? color.withOpacity(0.6) : color,
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
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!isLoading)
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

  void _handleLanguageSettings(
      BuildContext context, bool isAuthenticated) async {
    if (isAuthenticated) {
      await context.read<AuthCubit>().validateAndRefreshToken();

      if (mounted && context.read<AuthCubit>().isAuthenticated) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LanguageSelectionPage(),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to access language settings'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _handleFeatureAccess(BuildContext context, String matchType) async {
    final authCubit = context.read<AuthCubit>();

    if (!authCubit.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please login to access this feature'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Login',
            onPressed: () {
              // Navigate to login page
            },
          ),
        ),
      );
      return;
    }

    if (_isSearchingForMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already searching for a match'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSearchingForMatch = true;
      _currentSearchType = matchType;
    });

    try {
      await authCubit.validateAndRefreshToken();

      if (!mounted) return;

      final currentState = authCubit.state;
      if (currentState is! AuthAuthenticated) {
        setState(() {
          _isSearchingForMatch = false;
          _currentSearchType = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final match = await _matchingService.findMatch(matchType);

      if (!mounted) return;

      setState(() {
        _isSearchingForMatch = false;
        _currentSearchType = '';
      });

      if (match != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              match: match,
              matchingService: _matchingService,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No match found. Please try again later.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearchingForMatch = false;
        _currentSearchType = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to find match: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelSearch() {
    setState(() {
      _isSearchingForMatch = false;
      _currentSearchType = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search cancelled'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  void _resumeMatch(MatchResponse match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          match: match,
          matchingService: _matchingService,
        ),
      ),
    );
  }

  void _endMatch(MatchResponse match) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Match'),
        content: Text(
            'Are you sure you want to end the match with ${match.matchedUser.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Match', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success = await _matchingService.endMatch(match.id);
        if (success) {
          setState(() {}); // Refresh the matches list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Match ended successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to end match'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending match: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<MatchResponse>> _getActiveMatches() async {
    final authCubit = context.read<AuthCubit>();
    if (!authCubit.isAuthenticated) {
      return [];
    }

    try {
      return await _matchingService.getMatches();
    } catch (e) {
      throw Exception('Failed to load matches: $e');
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
