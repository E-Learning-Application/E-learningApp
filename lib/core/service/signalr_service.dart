import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:e_learning_app/core/model/message_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SignalRService {
  static const String _hubUrl =
      'https://elearningproject.runasp.net/messageHub';
  static const int _maxRetryAttempts = 5;
  static const int _reconnectDelay = 2000;

  HubConnection? _hubConnection;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _connectionId;
  int? _currentUserId;
  String? _accessToken;

  // Retry mechanism
  int _retryAttempt = 0;
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;

  // Connection health monitoring
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Message queue for offline scenarios
  final List<Map<String, dynamic>> _messageQueue = [];
  bool _isProcessingQueue = false;

  // Stream controllers
  final StreamController<Message> _messageReceivedController =
      StreamController<Message>.broadcast();
  final StreamController<Map<String, dynamic>> _messageStatusUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>>
      _userOnlineStatusChangedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userTypingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _matchFoundController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _matchEndedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<ConnectionState> _connectionStateController =
      StreamController<ConnectionState>.broadcast();

  // Public streams
  Stream<Message> get onMessageReceived => _messageReceivedController.stream;
  Stream<Map<String, dynamic>> get onMessageStatusUpdated =>
      _messageStatusUpdatedController.stream;
  Stream<Map<String, dynamic>> get onUserOnlineStatusChanged =>
      _userOnlineStatusChangedController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;
  Stream<Map<String, dynamic>> get onMatchFound => _matchFoundController.stream;
  Stream<Map<String, dynamic>> get onMatchEnded => _matchEndedController.stream;
  Stream<ConnectionState> get onConnectionStateChanged =>
      _connectionStateController.stream;

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get connectionId => _connectionId;
  int? get currentUserId => _currentUserId;
  int get queuedMessagesCount => _messageQueue.length;

  /// Initialize SignalR connection with enhanced error handling and retry logic
  Future<bool> initialize({
    required int userId,
    required String accessToken,
    bool enableAutoReconnect = true,
  }) async {
    try {
      if (_isConnecting) {
        log('SignalR already connecting, please wait...');
        return false;
      }

      _isConnecting = true;
      _currentUserId = userId;
      _accessToken = accessToken;

      // Check network connectivity first
      if (!await _hasNetworkConnection()) {
        log('No network connection available');
        _isConnecting = false;
        return false;
      }

      // Create hub connection with enhanced options
      _hubConnection = HubConnectionBuilder()
          .withUrl(_hubUrl,
              options: HttpConnectionOptions(
                accessTokenFactory: () => Future.value(accessToken),
                transport: HttpTransportType.WebSockets,
                skipNegotiation: true,
                requestTimeout: 30000, // 30 seconds
                logMessageContent: false,
              ))
          .withAutomaticReconnect(
        retryDelays: [2000, 5000, 10000, 30000], // Custom retry delays
      ).build();

      // Set up enhanced event handlers
      _setupEventHandlers();

      // Start connection with timeout
      await _hubConnection!.start()!.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Connection timeout after 30 seconds');
        },
      );

      _isConnected = true;
      _isConnecting = false;
      _connectionId = _hubConnection!.connectionId;
      _retryAttempt = 0;

      log('SignalR connected successfully. Connection ID: $_connectionId');

      // Join user to their personal group
      await _joinUserGroup(userId);

      // Start health check monitoring
      if (enableAutoReconnect) {
        _startHealthCheckMonitoring();
        _startConnectivityMonitoring();
      }

      // Process queued messages
      await _processMessageQueue();

      // Emit connection state
      _connectionStateController.add(ConnectionState.connected);

      return true;
    } catch (e) {
      log('SignalR connection failed: $e');
      _isConnected = false;
      _isConnecting = false;
      _connectionStateController.add(ConnectionState.disconnected);

      // Schedule retry if not at max attempts
      if (_retryAttempt < _maxRetryAttempts) {
        _scheduleReconnect();
      }

      return false;
    }
  }

  void _setupEventHandlers() {
    if (_hubConnection == null) return;

    _hubConnection!.onclose((Exception? error) {
      log('SignalR connection closed: $error');
      _isConnected = false;
      _connectionId = null;
      _connectionStateController.add(ConnectionState.disconnected);

      // Schedule reconnect
      _scheduleReconnect();
    } as ClosedCallback);

    _hubConnection!.onreconnecting((Exception? error) {
      log('SignalR reconnecting: $error');
      _isConnected = false;
      _connectionStateController.add(ConnectionState.reconnecting);
    } as ReconnectingCallback);

    _hubConnection!.onreconnected((String? connectionId) {
      log('SignalR reconnected. New connection ID: $connectionId');
      _isConnected = true;
      _connectionId = connectionId;
      _retryAttempt = 0;
      _connectionStateController.add(ConnectionState.connected);

      if (_currentUserId != null) {
        _joinUserGroup(_currentUserId!);
      }

      // Process queued messages
      _processMessageQueue();
    } as ReconnectedCallback);

    // Message handlers with enhanced error handling
    _hubConnection!.on('ReceiveMessage', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) {
          log('ReceiveMessage: No arguments received');
          return;
        }

        final messageData = arguments[0];
        if (messageData is! Map<String, dynamic>) {
          log('ReceiveMessage: Invalid message format');
          return;
        }

        final message = Message.fromJson(messageData);
        _messageReceivedController.add(message);
        log('Message received: ${message.content}');
      } catch (e) {
        log('Error parsing received message: $e');
      }
    });

    _hubConnection!.on('MessageStatusUpdated', (arguments) {
      try {
        if (arguments == null || arguments.length < 2) {
          log('MessageStatusUpdated: Insufficient arguments');
          return;
        }

        final messageId = arguments[0];
        final status = arguments[1];

        if (messageId is! int || status is! String) {
          log('MessageStatusUpdated: Invalid argument types');
          return;
        }

        _messageStatusUpdatedController.add({
          'messageId': messageId,
          'status': status,
          'timestamp': DateTime.now(),
        });
        log('Message status updated: $messageId -> $status');
      } catch (e) {
        log('Error parsing message status update: $e');
      }
    });

    _hubConnection!.on('UserOnlineStatusChanged', (arguments) {
      try {
        if (arguments == null || arguments.length < 2) {
          log('UserOnlineStatusChanged: Insufficient arguments');
          return;
        }

        final userId = arguments[0];
        final isOnline = arguments[1];

        if (userId is! int || isOnline is! bool) {
          log('UserOnlineStatusChanged: Invalid argument types');
          return;
        }

        _userOnlineStatusChangedController.add({
          'userId': userId,
          'isOnline': isOnline,
          'timestamp': DateTime.now(),
        });
        log('User online status changed: $userId -> $isOnline');
      } catch (e) {
        log('Error parsing user online status: $e');
      }
    });

    _hubConnection!.on('UserTyping', (arguments) {
      try {
        if (arguments == null || arguments.length < 2) {
          log('UserTyping: Insufficient arguments');
          return;
        }

        final userId = arguments[0];
        final isTyping = arguments[1];

        if (userId is! int || isTyping is! bool) {
          log('UserTyping: Invalid argument types');
          return;
        }

        _userTypingController.add({
          'userId': userId,
          'isTyping': isTyping,
          'timestamp': DateTime.now(),
        });
      } catch (e) {
        log('Error parsing user typing: $e');
      }
    });

    _hubConnection!.on('MatchFound', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) {
          log('MatchFound: No arguments received');
          return;
        }

        final matchData = arguments[0];
        if (matchData is! Map<String, dynamic>) {
          log('MatchFound: Invalid match data format');
          return;
        }

        _matchFoundController.add(matchData);
        log('Match found: ${matchData['id']}');
      } catch (e) {
        log('Error parsing match found: $e');
      }
    });

    _hubConnection!.on('MatchEnded', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) {
          log('MatchEnded: No arguments received');
          return;
        }

        final matchId = arguments[0];
        final reason = arguments.length > 1 ? arguments[1] : null;

        if (matchId is! int) {
          log('MatchEnded: Invalid matchId type');
          return;
        }

        _matchEndedController.add({
          'matchId': matchId,
          'reason': reason is String ? reason : null,
          'timestamp': DateTime.now(),
        });
        log('Match ended: $matchId, reason: $reason');
      } catch (e) {
        log('Error parsing match ended: $e');
      }
    });
  }

  /// Enhanced send message with retry logic and queuing
  Future<bool> sendMessage({
    required int receiverId,
    required String content,
    String messageType = 'text',
    int maxRetries = 3,
  }) async {
    final messageData = {
      'receiverId': receiverId,
      'content': content,
      'messageType': messageType,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // If not connected, queue the message
    if (!_isConnected) {
      _messageQueue.add(messageData);
      log('Message queued for later sending (offline)');
      return false;
    }

    // Retry logic
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _hubConnection!.invoke('SendMessage', args: [
          receiverId,
          content,
          messageType,
        ]).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Send message timeout');
          },
        );

        log('Message sent successfully to user $receiverId: $content');
        return true;
      } catch (e) {
        log('Error sending message (attempt $attempt/$maxRetries): $e');

        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt));
        } else {
          // Queue message for later retry
          _messageQueue.add(messageData);
          log('Message queued after all retry attempts failed');
        }
      }
    }

    return false;
  }

  /// Enhanced typing indicator with debouncing
  Timer? _typingTimer;
  Future<void> sendTypingIndicator({
    required int receiverId,
    required bool isTyping,
  }) async {
    try {
      if (!_isConnected || _hubConnection == null) return;

      // Cancel previous timer
      _typingTimer?.cancel();

      if (isTyping) {
        // Send typing indicator
        await _hubConnection!.invoke('SendTypingIndicator', args: [
          receiverId,
          true,
        ]);

        // Auto-stop typing after 3 seconds
        _typingTimer = Timer(const Duration(seconds: 3), () {
          sendTypingIndicator(receiverId: receiverId, isTyping: false);
        });
      } else {
        // Send stop typing indicator
        await _hubConnection!.invoke('SendTypingIndicator', args: [
          receiverId,
          false,
        ]);
      }

      log('Typing indicator sent to user $receiverId: $isTyping');
    } catch (e) {
      log('Error sending typing indicator: $e');
    }
  }

  /// Mark message as read with retry logic
  Future<bool> markMessageAsRead(int messageId) async {
    try {
      if (!_isConnected || _hubConnection == null) return false;

      await _hubConnection!.invoke('MarkMessageAsRead', args: [messageId]);
      log('Message marked as read: $messageId');
      return true;
    } catch (e) {
      log('Error marking message as read: $e');
      return false;
    }
  }

  /// Set online status
  Future<bool> setOnlineStatus(bool isOnline) async {
    try {
      if (!_isConnected || _hubConnection == null) return false;

      await _hubConnection!.invoke('SetOnlineStatus', args: [isOnline]);
      log('Online status set to: $isOnline');
      return true;
    } catch (e) {
      log('Error setting online status: $e');
      return false;
    }
  }

  /// Join user group
  Future<void> _joinUserGroup(int userId) async {
    try {
      await _hubConnection?.invoke('JoinUserGroup', args: [userId]);
      log('Joined user group: $userId');
    } catch (e) {
      log('Error joining user group: $e');
    }
  }

  /// Process queued messages
  Future<void> _processMessageQueue() async {
    if (_isProcessingQueue || _messageQueue.isEmpty || !_isConnected) return;

    _isProcessingQueue = true;
    final messagesToProcess = List<Map<String, dynamic>>.from(_messageQueue);
    _messageQueue.clear();

    for (final messageData in messagesToProcess) {
      try {
        final success = await sendMessage(
          receiverId: messageData['receiverId'],
          content: messageData['content'],
          messageType: messageData['messageType'] ?? 'text',
          maxRetries: 1, // Single retry for queued messages
        );

        if (!success) {
          // Re-queue failed message
          _messageQueue.add(messageData);
        }
      } catch (e) {
        log('Error processing queued message: $e');
        _messageQueue.add(messageData); // Re-queue on error
      }
    }

    _isProcessingQueue = false;
    log('Processed ${messagesToProcess.length} queued messages');
  }

  /// Health check monitoring
  void _startHealthCheckMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isConnected && !_isConnecting) {
        log('Health check: Connection lost, attempting reconnect...');
        _attemptReconnect();
      }
    });
  }

  /// Connectivity monitoring
  void _startConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      // Use the first result if available, otherwise assume no connectivity
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (result != ConnectivityResult.none &&
          !_isConnected &&
          !_isConnecting) {
        log('Network connectivity restored, attempting reconnect...');
        _attemptReconnect();
      }
    }) as StreamSubscription<ConnectivityResult>?;
  }

  /// Check network connection
  Future<bool> _hasNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Schedule reconnect
  void _scheduleReconnect() {
    if (_retryAttempt >= _maxRetryAttempts) {
      log('Max retry attempts reached. Stopping reconnect attempts.');
      return;
    }

    _reconnectTimer?.cancel();
    final delay = _reconnectDelay * (_retryAttempt + 1);

    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      _attemptReconnect();
    });
  }

  /// Attempt reconnect
  Future<void> _attemptReconnect() async {
    if (_isConnecting || _isConnected) return;

    _retryAttempt++;
    log('Attempting reconnect (attempt $_retryAttempt/$_maxRetryAttempts)...');

    if (_currentUserId != null && _accessToken != null) {
      await initialize(
        userId: _currentUserId!,
        accessToken: _accessToken!,
        enableAutoReconnect: false, // Prevent recursive calls
      );
    }
  }

  /// Disconnect with cleanup
  Future<void> disconnect() async {
    try {
      _healthCheckTimer?.cancel();
      _connectivitySubscription?.cancel();
      _reconnectTimer?.cancel();
      _typingTimer?.cancel();

      if (_hubConnection != null) {
        await _hubConnection!.stop();
        _isConnected = false;
        _connectionId = null;
        _connectionStateController.add(ConnectionState.disconnected);
        log('SignalR disconnected');
      }
    } catch (e) {
      log('Error disconnecting SignalR: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _messageReceivedController.close();
    _messageStatusUpdatedController.close();
    _userOnlineStatusChangedController.close();
    _userTypingController.close();
    _matchFoundController.close();
    _matchEndedController.close();
    _connectionStateController.close();

    _messageQueue.clear();
    disconnect();
  }

  /// Safe invoke with error handling
  Future<T?> safeInvoke<T>(String methodName, {List<Object>? args}) async {
    try {
      if (!isConnected || _hubConnection == null) {
        log('SignalR not connected, cannot invoke $methodName');
        return null;
      }

      final result = await _hubConnection!.invoke(methodName, args: args);
      return result as T?;
    } catch (e) {
      log('Error invoking $methodName: $e');
      return null;
    }
  }

  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': _isConnected,
      'isConnecting': _isConnecting,
      'connectionId': _connectionId,
      'retryAttempt': _retryAttempt,
      'queuedMessages': _messageQueue.length,
      'currentUserId': _currentUserId,
    };
  }
}

/// Connection state enum
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}
