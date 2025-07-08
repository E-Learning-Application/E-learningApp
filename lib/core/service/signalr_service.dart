import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:e_learning_app/core/model/message_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SignalRService {
  static const String _hubUrl =
      'https://elearningproject.runasp.net/messageHub';
  static const int _maxRetryAttempts = 3;
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

  // Public streams
  Stream<Message> get onMessageReceived => _messageReceivedController.stream;
  Stream<Map<String, dynamic>> get onMatchFound => _matchFoundController.stream;
  Stream<String> get onWebRtcSignal => _webRtcSignalController.stream;
  Stream<ConnectionState> get onConnectionStateChanged =>
      _connectionStateController.stream;

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get connectionId => _connectionId;
  int? get currentUserId => _currentUserId;
  int get queuedMessagesCount => _messageQueue.length;

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

      // Create hub connection
      _hubConnection = HubConnectionBuilder()
          .withUrl(_hubUrl,
              options: HttpConnectionOptions(
                accessTokenFactory: () => Future.value(accessToken),
                transport: HttpTransportType.WebSockets,
                skipNegotiation: true,
                requestTimeout: 30000,
              ))
          .withAutomaticReconnect(
        retryDelays: [2000, 5000, 10000],
      ).build();

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

    _hubConnection!.onclose((Exception? error) {
      log('SignalR connection closed: $error');
      _isConnected = false;
      _connectionId = null;
      _connectionStateController.add(ConnectionState.disconnected);
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
      _processMessageQueue();
    } as ReconnectedCallback);

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
        await _hubConnection!.invoke('SendMessageAsync', args: [
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

  /// Request match
  Future<bool> requestMatch(String matchType) async {
    try {
      if (!_isConnected || _hubConnection == null) return false;

      await _hubConnection!.invoke('RequestMatchAsync', args: [matchType]);
      log('Match request sent for type: $matchType');
      return true;
    } catch (e) {
      log('Error requesting match: $e');
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
