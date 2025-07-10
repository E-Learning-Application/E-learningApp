import 'package:e_learning_app/core/model/match_response.dart';
import 'package:e_learning_app/core/service/matching_service.dart';
import 'package:e_learning_app/core/service/signalr_service.dart';
import 'package:e_learning_app/core/service/webrtc_service.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/feature/Auth/data/auth_cubit.dart';
import 'package:e_learning_app/feature/Auth/data/auth_state.dart';
import 'package:e_learning_app/feature/language/presentation/view/language_view.dart';
import 'package:e_learning_app/feature/messages/presentation/views/chat_screen.dart';
import 'package:e_learning_app/feature/call/presentation/views/call_screen.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:developer';
import 'package:e_learning_app/core/model/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final MatchingService _matchingService;
  late final SignalRService _signalRService;
  late final WebRTCService _webRTCService;

  bool _isSearchingForMatch = false;
  String _currentSearchType = '';
  Timer? _matchTimeoutTimer;
  StreamSubscription? _matchFoundSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _webRtcSignalSubscription;

  ConnectionState _signalRConnectionState = ConnectionState.disconnected;
  MatchResponse? _currentMatch;

  static const Duration _matchTimeout = Duration(seconds: 30);

  String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    const baseUrl = 'https://elearningproject.runasp.net';
    return '$baseUrl$path';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _setupSignalRListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSignalRConnection();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupSubscriptions();
    _matchTimeoutTimer?.cancel();
    _signalRService.disconnect();
    _webRTCService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _reconnectSignalRIfNeeded();
        break;
      case AppLifecycleState.paused:
        _pauseServices();
        break;
      case AppLifecycleState.detached:
        _signalRService.disconnect();
        break;
      default:
        break;
    }
  }

  void _initializeServices() {
    _matchingService = MatchingService(
      dioConsumer: context.read<DioConsumer>(),
      authService: context.read<AuthService>(),
    );

    _signalRService = context.read<SignalRService>();
    _webRTCService = WebRTCService();
  }

  void _setupSignalRListeners() {
    // Listen for match found events
    _matchFoundSubscription = _signalRService.onMatchFound.listen((matchData) {
      _handleMatchFound(matchData);
    });

    _connectionStateSubscription =
        _signalRService.onConnectionStateChanged.listen((state) {
      setState(() {
        _signalRConnectionState = state;
      });
    });

    _webRtcSignalSubscription = _signalRService.onWebRtcSignal.listen((signal) {
      _handleWebRtcSignal(signal);
    });
  }

  void _cleanupSubscriptions() {
    _matchFoundSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _webRtcSignalSubscription?.cancel();
  }

  Future<void> _initializeSignalRConnection() async {
    final authCubit = context.read<AuthCubit>();
    final state = authCubit.state;

    bool isAuthenticated = false;
    User? user;
    String? accessToken;

    if (state is AuthAuthenticated) {
      isAuthenticated = true;
      user = state.user;
      accessToken = state.accessToken;
    } else if (state is LoginSuccess) {
      isAuthenticated = true;
      user = state.user;
      accessToken = state.accessToken;
    } else {
      try {
        user = await context.read<AuthService>().getCurrentUser();
        accessToken = await context.read<AuthService>().getAccessToken();

        if (user != null && accessToken != null) {
          isAuthenticated = true;
        }
      } catch (e) {
        log('Error checking auth service directly: $e');
      }
    }

    if (isAuthenticated && user != null && accessToken != null) {
      await _signalRService.initialize(
        userId: user.userId,
        accessToken: accessToken,
        enableAutoReconnect: true,
      );
    }
  }

  Future<void> _reconnectSignalRIfNeeded() async {
    if (!_signalRService.isConnected && !_signalRService.isConnecting) {
      await _initializeSignalRConnection();
    }
  }

  void _pauseServices() {
    if (_isSearchingForMatch) {
      _cancelSearch();
    }
  }

  void _handleMatchFound(Map<String, dynamic> matchData) {
    try {
      final currentUserId = _signalRService.currentUserId;
      if (currentUserId == null) throw Exception('Current user ID is null');
      final match = MatchResponse.fromJson(matchData, currentUserId);

      setState(() {
        _isSearchingForMatch = false;
        _currentMatch = match;
      });

      _matchTimeoutTimer?.cancel();

      // Show match found dialog
      _showMatchFoundDialog(match);
    } catch (e) {
      log('Error parsing match data: $e');
      _handleMatchError('Invalid match data received');
    }
  }

  void _handleWebRtcSignal(String signal) {
    if (_currentMatch != null) {
      _webRTCService.handleSignal(signal);
    }
  }

  void _showMatchFoundDialog(MatchResponse match) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Match Found!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: match.matchedUser.profilePicture != null
                  ? NetworkImage(
                      getFullImageUrl(match.matchedUser.profilePicture!))
                  : null,
              child: match.matchedUser.profilePicture == null
                  ? Text(
                      match.matchedUser.username[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              match.matchedUser.username,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Match Type: ${match.matchType.toUpperCase()}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _declineMatch(match),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () => _acceptMatch(match),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptMatch(MatchResponse match) async {
    Navigator.pop(context); // Close dialog

    try {
      if (match.matchType == 'text') {
        // Navigate to chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              match: match,
              matchingService: _matchingService,
              signalRService: _signalRService,
            ),
          ),
        );
      } else {
        // Initialize WebRTC and navigate to call screen
        await _webRTCService.initialize();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallScreen(
              match: match,
              webRTCService: _webRTCService,
              signalRService: _signalRService,
              isVideo: match.matchType == 'video',
            ),
          ),
        );
      }
    } catch (e) {
      log('Error accepting match: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start ${match.matchType}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _declineMatch(MatchResponse match) async {
    Navigator.pop(context);

    try {
      await _matchingService.endMatch(match.id);
      setState(() {
        _currentMatch = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match declined'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      log('Error declining match: $e');
    }
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
                _buildConnectionStatus(),
                // const SizedBox(height: 10),
                // _buildDebugSection(),
                const SizedBox(height: 10),
                if (_isSearchingForMatch) _buildSearchingIndicator(),
                const SizedBox(height: 20),
                _buildFeatureOptions(),
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

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getConnectionStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getConnectionStatusColor().withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getConnectionStatusColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getConnectionStatusText(),
              style: TextStyle(
                color: _getConnectionStatusColor(),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_signalRConnectionState == ConnectionState.disconnected)
            TextButton(
              onPressed: _reconnectSignalRIfNeeded,
              child: const Text('Reconnect'),
            ),
        ],
      ),
    );
  }

  Color _getConnectionStatusColor() {
    switch (_signalRConnectionState) {
      case ConnectionState.connected:
        return Colors.green;
      case ConnectionState.connecting:
      case ConnectionState.reconnecting:
        return Colors.orange;
      case ConnectionState.disconnected:
        return Colors.red;
      case ConnectionState.waiting:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  String _getConnectionStatusText() {
    switch (_signalRConnectionState) {
      case ConnectionState.connected:
        return 'Connected • Ready for matching';
      case ConnectionState.connecting:
        return 'Connecting...';
      case ConnectionState.reconnecting:
        return 'Reconnecting...';
      case ConnectionState.disconnected:
        return 'Disconnected • Matching unavailable';
      case ConnectionState.waiting:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Searching for $_currentSearchType match...',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This may take up to 30 seconds',
                  style: TextStyle(
                    color: Colors.blue.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
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
          isEnabled: _signalRConnectionState == ConnectionState.connected,
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
          isEnabled: _signalRConnectionState == ConnectionState.connected,
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
          isEnabled: _signalRConnectionState == ConnectionState.connected,
        ),
      ],
    );
  }

  Widget _buildCallOption({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: isLoading || !isEnabled ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: !isEnabled
              ? Colors.grey[400]
              : isLoading
                  ? color.withOpacity(0.6)
                  : color,
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
                    !isEnabled ? 'Connection required' : subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!isLoading && isEnabled)
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
      // Start match timeout timer
      _matchTimeoutTimer = Timer(_matchTimeout, () {
        _handleMatchTimeout();
      });

      if (_signalRConnectionState != ConnectionState.connected) {
        // Initialize SignalR connection if not already connected
        if (!_signalRService.isConnected) {
          await _initializeSignalRConnection();
        }

        if (!_signalRService.isConnected) {
          throw Exception('Unable to connect to matching service');
        }
      }

      // Request match through SignalR only
      final success = await _signalRService.requestMatch(matchType);

      if (!success) {
        throw Exception('Failed to request match via SignalR');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearchingForMatch = false;
        _currentSearchType = '';
      });

      _matchTimeoutTimer?.cancel();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request match: 24{e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleMatchTimeout() {
    if (!mounted) return;

    setState(() {
      _isSearchingForMatch = false;
      _currentSearchType = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No match found. Please try again later.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _handleMatchError(String error) {
    if (!mounted) return;

    setState(() {
      _isSearchingForMatch = false;
      _currentSearchType = '';
    });

    _matchTimeoutTimer?.cancel();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _cancelSearch() {
    setState(() {
      _isSearchingForMatch = false;
      _currentSearchType = '';
    });

    _matchTimeoutTimer?.cancel();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search cancelled'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  void _resumeMatch(MatchResponse match) {
    if (match.matchType == 'text') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            match: match,
            matchingService: _matchingService,
            signalRService: _signalRService,
          ),
        ),
      );
    } else {
      // Resume video/voice call
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreen(
            match: match,
            webRTCService: _webRTCService,
            signalRService: _signalRService,
            isVideo: match.matchType == 'video',
          ),
        ),
      );
    }
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

  Widget _buildDebugSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug Tools',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _testServerConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    'Test Server',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _testSignalRConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    'Test SignalR',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _testServerConnection() async {
    try {
      final result = await _matchingService.testServerConnection();
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Server Test: ${result['status']} - User: ${result['currentUser']} - Matches: ${result['matches']}'),
            backgroundColor:
                result['status'] == 'connected' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server Test Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testSignalRConnection() async {
    try {
      final success = await _signalRService.testConnection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SignalR Test: ${success ? 'Connected' : 'Failed'}'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SignalR Test Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
