import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:signalr_netcore/ihub_protocol.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:e_learning_app/core/model/message_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';

class SignalRService {
  static const String _hubUrl = 'https://elearningproject.runasp.net/chatHub';
  static const int _maxRetryAttempts = 3;
  static const int _reconnectDelay = 2000;

  HubConnection? _hubConnection;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _connectionId;
  int? _currentUserId;
  String? _accessToken;

  // Available server methods (hardcoded based on server implementation)
  Set<String> _availableServerMethods = {'RequestMatchAsync'};

  // Retry mechanism
  int _retryAttempt = 0;
  Timer? _reconnectTimer;

  // Connection monitoring
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Message queue for offline scenarios
  final List<Map<String, dynamic>> _messageQueue = [];

  // Stream controllers
  final StreamController<Message> _messageReceivedController =
      StreamController<Message>.broadcast();
  final StreamController<Map<String, dynamic>> _matchFoundController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _webRtcSignalController =
      StreamController<String>.broadcast();
  final StreamController<ConnectionState> _connectionStateController =
      StreamController<ConnectionState>.broadcast();
  final StreamController<String> _matchRequestStatusController =
      StreamController<String>.broadcast();

  // Public streams
  Stream<Message> get onMessageReceived => _messageReceivedController.stream;
  Stream<Map<String, dynamic>> get onMatchFound => _matchFoundController.stream;
  Stream<String> get onWebRtcSignal => _webRtcSignalController.stream;
  Stream<ConnectionState> get onConnectionStateChanged =>
      _connectionStateController.stream;
  Stream<String> get onMatchRequestStatus =>
      _matchRequestStatusController.stream;

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get connectionId => _connectionId;
  int? get currentUserId => _currentUserId;
  int get queuedMessagesCount => _messageQueue.length;
  Set<String> get availableServerMethods => Set.from(_availableServerMethods);

  /// Helper method to create MessageHeaders
  MessageHeaders _createMessageHeaders(Map<String, String> headers) {
    final messageHeaders = MessageHeaders();
    headers.forEach((key, value) {
      messageHeaders.setHeaderValue(key, value);
    });
    return messageHeaders;
  }

  /// Initialize SignalR connection
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

      // Check network connectivity
      if (!await _hasNetworkConnection()) {
        log('No network connection available');
        _isConnecting = false;
        return false;
      }

      // Create hub connection with proper configuration
      _hubConnection = HubConnectionBuilder()
          .withUrl(_hubUrl,
              options: HttpConnectionOptions(
                accessTokenFactory: () => Future.value(accessToken),
                transport: HttpTransportType.WebSockets,
                skipNegotiation: false,
                requestTimeout: 30000,
                headers: _createMessageHeaders({
                  'Authorization': 'Bearer $accessToken',
                }),
              ))
          .withAutomaticReconnect(
            retryDelays: [2000, 5000, 10000],
          )
          .configureLogging(Logger('SignalR'))
          .build();

      // Set up event handlers
      _setupEventHandlers();

      // Start connection
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

      // Start connectivity monitoring
      if (enableAutoReconnect) {
        _startConnectivityMonitoring();
      }

      // Process queued messages
      await _processMessageQueue();

      _connectionStateController.add(ConnectionState.connected);
      return true;
    } catch (e) {
      log('SignalR connection failed: $e');
      _isConnected = false;
      _isConnecting = false;
      _connectionStateController.add(ConnectionState.disconnected);

      if (_retryAttempt < _maxRetryAttempts) {
        _scheduleReconnect();
      }

      return false;
    }
  }

  void _setupEventHandlers() {
    if (_hubConnection == null) return;

    // Connection state handlers
    _hubConnection!.onclose(({Exception? error}) {
      log('SignalR connection closed: $error');
      _isConnected = false;
      _connectionId = null;
      _availableServerMethods.clear();
      _connectionStateController.add(ConnectionState.disconnected);
      _scheduleReconnect();
    });

    _hubConnection!.onreconnecting(({Exception? error}) {
      log('SignalR reconnecting: $error');
      _isConnected = false;
      _connectionStateController.add(ConnectionState.reconnecting);
    });

    _hubConnection!.onreconnected(({String? connectionId}) {
      log('SignalR reconnected. New connection ID: $connectionId');
      _isConnected = true;
      _connectionId = connectionId;
      _retryAttempt = 0;
      _connectionStateController.add(ConnectionState.connected);
      _processMessageQueue();
    });

    // Message handlers
    _hubConnection!.on('ReceiveMessage', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) return;

        final messageData = arguments[0] as Map<String, dynamic>;
        final message = Message.fromJson(messageData);
        _messageReceivedController.add(message);
        log('Message received: ${message.content}');
      } catch (e) {
        log('Error parsing received message: $e');
      }
    });

    _hubConnection!.on('MatchFound', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) return;

        final matchData = arguments[0] as Map<String, dynamic>;
        _matchFoundController.add(matchData);
        log('Match found: ${matchData['id']}');
      } catch (e) {
        log('Error parsing match found: $e');
      }
    });

    _hubConnection!.on('ReceiveWebRtcSignal', (arguments) {
      try {
        if (arguments == null || arguments.length < 2) return;

        final fromUserId = arguments[0] as String;
        final signalData = arguments[1] as String;

        _webRtcSignalController.add(signalData);
        log('WebRTC signal received from user $fromUserId');
      } catch (e) {
        log('Error parsing WebRTC signal: $e');
      }
    });

    // Enhanced match request handlers
    _hubConnection!.on('MatchRequestReceived', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) return;
        final matchType = arguments[0] as String;
        _matchRequestStatusController
            .add('Match request received for: $matchType');
        log('Match request received for type: $matchType');
      } catch (e) {
        log('Error parsing match request confirmation: $e');
      }
    });

    _hubConnection!.on('MatchRequestError', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) return;
        final error = arguments[0] as String;
        _matchRequestStatusController.add('Match request error: $error');
        log('Match request error: $error');
      } catch (e) {
        log('Error parsing match request error: $e');
      }
    });

    // Additional match-related events
    _hubConnection!.on('MatchRequestSuccess', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) return;
        final message = arguments[0] as String;
        _matchRequestStatusController.add('Match request successful: $message');
        log('Match request successful: $message');
      } catch (e) {
        log('Error parsing match request success: $e');
      }
    });

    _hubConnection!.on('QueueJoined', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) return;
        final queueInfo = arguments[0] as String;
        _matchRequestStatusController.add('Joined queue: $queueInfo');
        log('Joined queue: $queueInfo');
      } catch (e) {
        log('Error parsing queue joined: $e');
      }
    });
  }

  /// Send message with retry logic
  Future<bool> sendMessage({
    required int receiverId,
    required String content,
    int maxRetries = 3,
  }) async {
    final messageData = {
      'receiverId': receiverId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Queue if offline
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
        ]).timeout(const Duration(seconds: 10));

        log('Message sent successfully to user $receiverId');
        return true;
      } catch (e) {
        log('Error sending message (attempt $attempt/$maxRetries): $e');

        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt));
        } else {
          _messageQueue.add(messageData);
          log('Message queued after all retry attempts failed');
        }
      }
    }

    return false;
  }

  /// Request match with correct method and error handling
  Future<bool> requestMatch(String matchType) async {
    try {
      if (!_isConnected || _hubConnection == null) {
        log('SignalR not connected, cannot request match');
        return false;
      }

      log('Requesting match for type: $matchType');

      // Only try the supported method
      try {
        await _hubConnection!.invoke(
          'RequestMatchAsync',
          args: [matchType],
        ).timeout(
          const Duration(seconds: 10),
        );

        log('Match request sent successfully using method: RequestMatchAsync');
        return true;
      } catch (e) {
        log('RequestMatchAsync failed: $e');
        _matchRequestStatusController.add('Match request error: $e');
        return false;
      }
    } catch (e) {
      log('Error requesting match: $e');
      _matchRequestStatusController.add('Match request error: $e');
      return false;
    }
  }

  /// Send WebRTC signal
  Future<bool> sendWebRtcSignal({
    required String targetUserId,
    required String signalData,
  }) async {
    try {
      if (!_isConnected || _hubConnection == null) return false;

      await _hubConnection!.invoke('SendWebRtcSignal', args: [
        targetUserId,
        signalData,
      ]);
      log('WebRTC signal sent to user $targetUserId');
      return true;
    } catch (e) {
      log('Error sending WebRTC signal: $e');
      return false;
    }
  }

  /// Process queued messages
  Future<void> _processMessageQueue() async {
    if (_messageQueue.isEmpty || !_isConnected) return;

    final messagesToProcess = List<Map<String, dynamic>>.from(_messageQueue);
    _messageQueue.clear();

    for (final messageData in messagesToProcess) {
      try {
        await sendMessage(
          receiverId: messageData['receiverId'],
          content: messageData['content'],
          maxRetries: 1,
        );
      } catch (e) {
        log('Error processing queued message: $e');
        _messageQueue.add(messageData); // Re-queue on error
      }
    }

    log('Processed ${messagesToProcess.length} queued messages');
  }

  /// Test connection with server
  Future<bool> testConnection() async {
    try {
      if (!_isConnected || _hubConnection == null) return false;

      // Try to invoke a method that exists, or just check connection state
      if (_hubConnection!.state == HubConnectionState.Connected) {
        log('Connection test successful - SignalR is connected');
        return true;
      } else {
        log('Connection test failed - SignalR not in connected state: ${_hubConnection!.state}');
        return false;
      }
    } catch (e) {
      log('Connection test failed: $e');
      return false;
    }
  }

  /// Connectivity monitoring
  void _startConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
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
        enableAutoReconnect: false,
      );
    }
  }

  /// Disconnect with cleanup
  Future<void> disconnect() async {
    try {
      _connectivitySubscription?.cancel();
      _reconnectTimer?.cancel();

      if (_hubConnection != null) {
        await _hubConnection!.stop();
        _isConnected = false;
        _connectionId = null;
        _availableServerMethods.clear();
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
    _matchFoundController.close();
    _webRtcSignalController.close();
    _connectionStateController.close();
    _matchRequestStatusController.close();
    _messageQueue.clear();
    disconnect();
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
      'availableServerMethods': _availableServerMethods.toList(),
    };
  }
}

/// Connection state enum
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  waiting,
}
