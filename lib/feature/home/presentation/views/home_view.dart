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
import 'package:e_learning_app/feature/home/presentation/views/unified_call_view.dart';
import 'package:e_learning_app/feature/home/data/call_cubit.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:developer';
import 'package:e_learning_app/core/model/user_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:e_learning_app/feature/profile/data/user_cubit.dart';
import 'package:e_learning_app/feature/profile/data/user_state.dart'
    as profile_state;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final MatchingService _matchingService;
  late final SignalRService _signalRService;

  bool _isSearchingForMatch = false;
  String _currentSearchType = '';
  Timer? _matchTimeoutTimer;

  // Stream subscriptions
  StreamSubscription? _matchFoundSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _webRtcSignalSubscription;

  ConnectionState _signalRConnectionState = ConnectionState.disconnected;
  MatchResponse? _currentMatch;
  CallState _currentCallState = CallState.idle;

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
    _setupWebRTCListeners();
    _requestPermissionsOnStart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSignalRConnection();
    });
    final callCubit = context.read<CallCubit>();
    callCubit.stream.listen((state) {
      if (state is IncomingCallReceived) {
        // For match-based calls, we don't want to show incoming call dialog
        // Only show dialog for direct calls (not from matching)
        if (_currentMatch == null) {
          _showIncomingCallDialog(IncomingCall(
            callerId: state.callerId,
            callId: state.callId,
            isVideo: state.isVideo,
          ));
        }
      } else if (state is CallConnected) {
        // Only navigate if we have a valid match or if this is an incoming call
        if (_currentMatch != null && state.targetUserId.isNotEmpty) {
          debugPrint(
              '[DEBUG] Navigating to call screen for match: ${_currentMatch!.matchedUser.username}, type: ${state.isVideo ? 'video' : 'voice'}');
          _navigateToCallScreenWithType(
              _currentMatch!, state.isVideo ? 'video' : 'voice');
        } else if (state.targetUserId.isNotEmpty) {
          // This is an incoming call that was accepted
          debugPrint(
              '[DEBUG] Navigating to call screen for incoming call: ${state.targetUserId}, type: ${state.isVideo ? 'video' : 'voice'}');
          _handleIncomingCallNavigation(state.targetUserId, state.isVideo);
        } else {
          debugPrint(
              '[DEBUG] CallConnected but no valid targetUserId, skipping navigation');
        }
      } else if (state is CallFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error),
            backgroundColor: Colors.red,
          ),
        );
        // Clear the current match when call fails
        setState(() {
          _currentMatch = null;
        });
      } else if (state is CallEnded) {
        // Handle call ended state
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call ended: ${state.reason}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        // Clear the current match when call ends
        setState(() {
          _currentMatch = null;
        });
      }
    });
  }

  Future<void> _requestPermissionsOnStart() async {
    try {
      final microphoneStatus = await Permission.microphone.request();
      if (microphoneStatus != PermissionStatus.granted) {
        debugPrint('Microphone permission not granted');
      }

      // Pre-request camera permission for video calls
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        debugPrint('Camera permission not granted');
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  void _showPermissionSettingsDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionType Permission Required'),
        content: Text(
            '$permissionType permission is required for calls. Please grant permission in app settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupSubscriptions();
    _matchTimeoutTimer?.cancel();
    _signalRService.disconnect();
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
    context.read<CallCubit>();
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
      log('WebRTC signal received in HomeScreen: $signal');
    });
  }

  void _setupWebRTCListeners() {}

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
    debugPrint('Match found event received: \n');
    debugPrint(matchData.toString());
    try {
      final currentUserId = _signalRService.currentUserId;
      if (currentUserId == null) throw Exception('Current user ID is null');
      final match = MatchResponse.fromJson(matchData, currentUserId);
      debugPrint('=== DEBUG: Match found ===');
      debugPrint('Backend returned match type: ${match.matchType}');
      debugPrint('User selected type: $_currentSearchType');
      debugPrint('Will use user selection: $_currentSearchType');
      debugPrint('Match data: ${matchData.toString()}');

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

  Future<void> _handleIncomingCallNavigation(
      String targetUserId, bool isVideo) async {
    try {
      final userCubit = context.read<UserCubit>();
      await userCubit.getUserById(int.parse(targetUserId));

      final userState = userCubit.state;
      String targetUserName = 'User';

      if (userState is profile_state.UserSuccess && userState.data != null) {
        targetUserName = userState.data!.username;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UnifiedCallPage(
            targetUserId: targetUserId,
            targetUserName: targetUserName,
            isVideoCall: isVideo,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[DEBUG] Error fetching user info: $e');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UnifiedCallPage(
            targetUserId: targetUserId,
            targetUserName: 'User $targetUserId',
            isVideoCall: isVideo,
          ),
        ),
      );
    }
  }

  void _showIncomingCallDialog(IncomingCall incomingCall) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(incomingCall.isVideo
            ? 'Incoming Video Call'
            : 'Incoming Voice Call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              incomingCall.isVideo ? Icons.videocam : Icons.call,
              size: 64,
              color: incomingCall.isVideo ? Colors.blue : Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'From: ${incomingCall.callerId}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _rejectIncomingCall(),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => _acceptIncomingCall(incomingCall),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptIncomingCall(IncomingCall incomingCall) async {
    Navigator.pop(context); // Close dialog

    try {
      // Don't navigate immediately - let the CallCubit state change handle navigation
      await context.read<CallCubit>().acceptIncomingCall(
            incomingCall.callerId,
            incomingCall.isVideo,
          );

      // The navigation will be handled in the CallCubit listener when CallConnected state is emitted
    } catch (e) {
      log('Error accepting incoming call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectIncomingCall() async {
    Navigator.pop(context); // Close dialog

    try {
      await context.read<CallCubit>().rejectIncomingCall();
    } catch (e) {
      log('Error rejecting incoming call: $e');
    }
  }

  void _showMatchFoundDialog(MatchResponse match) {
    String effectiveMatchType = _currentSearchType;

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
              'Match Type: ${effectiveMatchType.toUpperCase()}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            Text(
              '(Backend always returns text, using your selection)',
              style: TextStyle(
                color: Colors.blue[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
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
      String effectiveMatchType =
          _currentSearchType.isNotEmpty ? _currentSearchType : 'voice';
      debugPrint(
          '=== DEBUG: Using original search type: $effectiveMatchType (backend returned: ${match.matchType}) ===');
      debugPrint(
          '=== DEBUG: _currentSearchType was: "$_currentSearchType" ===');

      if (effectiveMatchType == 'video') {
        if (!await Permission.camera.isGranted ||
            !await Permission.microphone.isGranted) {
          _showPermissionSettingsDialog('Camera and Microphone');
          throw Exception(
              'Camera and microphone permissions required for video calls');
        }
      } else if (effectiveMatchType == 'voice') {
        if (!await Permission.microphone.isGranted) {
          _showPermissionSettingsDialog('Microphone');
          throw Exception('Microphone permission required for voice calls');
        }
      }

      if (effectiveMatchType == 'text') {
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
        final callCubit = context.read<CallCubit>();

        // Use user ID comparison to determine who initiates the call
        // Lower ID starts the call to prevent conflicts
        final currentUserId = _signalRService.currentUserId;
        final matchedUserId = match.matchedUser.id;

        if (currentUserId != null) {
          final shouldInitiateCall = int.parse(currentUserId.toString()) <
              int.parse(matchedUserId.toString());

          if (shouldInitiateCall) {
            // This user will initiate the call
            debugPrint(
                '[DEBUG] This user will initiate the call (ID: $currentUserId < ${matchedUserId})');

            if (effectiveMatchType == 'video') {
              await callCubit.startVideoCall(match.matchedUser.id.toString());
            } else {
              await callCubit.startVoiceCall(match.matchedUser.id.toString());
            }
          } else {
            // This user will wait for the other to initiate
            debugPrint(
                '[DEBUG] This user will wait for call (ID: $currentUserId >= ${matchedUserId})');

            // Wait for incoming call
            // The call will be handled automatically when the offer is received
          }
        } else {
          // Fallback: both try to initiate (original behavior)
          debugPrint('[DEBUG] Fallback: both users will try to initiate call');
          await Future.delayed(const Duration(milliseconds: 500));

          if (effectiveMatchType == 'video') {
            await callCubit.startVideoCall(match.matchedUser.id.toString());
          } else {
            await callCubit.startVoiceCall(match.matchedUser.id.toString());
          }
        }
      }
    } catch (e) {
      log('Error accepting match: $e');

      String errorMessage =
          'Failed to start ${_currentSearchType.isNotEmpty ? _currentSearchType : 'voice'}: $e';

      if (e.toString().contains('Permission denied') ||
          e.toString().contains('microphone')) {
        errorMessage =
            'Microphone permission is required for calls. Please grant permission in settings.';

        _showPermissionSettingsDialog('Microphone');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _navigateToCallScreenWithType(
      MatchResponse match, String effectiveMatchType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedCallPage(
          targetUserId: match.matchedUser.id.toString(),
          targetUserName: match.matchedUser.username,
          isVideoCall: effectiveMatchType == 'video',
        ),
      ),
    );
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
                const SizedBox(height: 10),
                if (_currentCallState != CallState.idle) _buildCallStatus(),
                if (_isSearchingForMatch) _buildSearchingIndicator(),
                const SizedBox(height: 20),
                _buildFeatureOptions(),
                const SizedBox(height: 30),
                _buildPermissionWarningBar(),
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

  Widget _buildCallStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getCallStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getCallStatusColor().withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getCallStatusColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getCallStatusText(),
              style: TextStyle(
                color: _getCallStatusColor(),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_currentCallState == CallState.connected)
            TextButton(
              onPressed: () => context.read<CallCubit>().endCall(),
              child: const Text('End Call'),
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
        return Colors.blue;
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
        return 'Waiting for connection...';
    }
  }

  Color _getCallStatusColor() {
    switch (_currentCallState) {
      case CallState.connecting:
        return Colors.orange;
      case CallState.connected:
        return Colors.green;
      case CallState.failed:
      case CallState.rejected:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getCallStatusText() {
    switch (_currentCallState) {
      case CallState.connecting:
        return 'Connecting call...';
      case CallState.connected:
        return 'In call • ${context.read<CallCubit>().isVideoCall ? 'Video' : 'Voice'}';
      case CallState.failed:
        return 'Call failed';
      case CallState.rejected:
        return 'Call rejected';
      case CallState.ended:
        return 'Call ended';
      default:
        return 'Call idle';
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
          isEnabled: _signalRConnectionState == ConnectionState.connected &&
              _currentCallState == CallState.idle,
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
          isEnabled: _signalRConnectionState == ConnectionState.connected &&
              _currentCallState == CallState.idle,
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
                    !isEnabled ? _getDisabledReason() : subtitle,
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

  String _getDisabledReason() {
    if (_signalRConnectionState != ConnectionState.connected) {
      return 'Connection required';
    }
    if (_currentCallState != CallState.idle) {
      return 'Call in progress';
    }
    return 'Unavailable';
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

    // Add debug logging
    debugPrint('=== DEBUG: User clicked ${matchType.toUpperCase()} button ===');
    debugPrint('User selected match type: $matchType');

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

    if (_currentCallState != CallState.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot search while in a call'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Use the matching system for all match types (text, video, voice)
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

      // Request match through SignalR for all types
      debugPrint(
          'Sending match request to backend with user selection: $matchType');
      final success = await _signalRService.requestMatch(matchType);

      if (!success) {
        throw Exception('Failed to request match via SignalR');
      }

      debugPrint(
          'Match request sent successfully - will use user selection regardless of backend response');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearchingForMatch = false;
        _currentSearchType = '';
      });

      _matchTimeoutTimer?.cancel();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request match: ${e.toString()}'),
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

  Widget _buildPermissionWarningBar() {
    return FutureBuilder(
      future: _getMissingPermissionType(),
      builder: (context, AsyncSnapshot<String?> snapshot) {
        if (snapshot.connectionState.toString() != 'ConnectionState.done' ||
            snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final type = snapshot.data!;
        String message;
        if (type == 'video') {
          message =
              'Camera and microphone permissions are required for video calls';
        } else if (type == 'voice') {
          message = 'Microphone permission is required for voice calls';
        } else {
          return const SizedBox.shrink();
        }
        return Container(
          color: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                },
                child: const Text(
                  'Open Settings',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _getMissingPermissionType() async {
    if (!await Permission.camera.isGranted ||
        !await Permission.microphone.isGranted) {
      return 'video';
    }
    if (!await Permission.microphone.isGranted) {
      return 'voice';
    }
    return null;
  }
}
