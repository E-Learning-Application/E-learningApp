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
  static const int _maxRetryAttempts = 5;
  static const int _reconnectDelay = 3000;
  static const int _connectionTimeout = 30;

  HubConnection? _hubConnection;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _connectionId;
  int? _currentUserId;
  String? _accessToken;

  final Set<String> _availableServerMethods = {
    'RequestMatchAsync',
    'SendMessageAsync',
    'SendTypingIndicator',
    'SendWebRtcSignal',
    'JoinGroup',
    'LeaveGroup'
  };

  int _retryAttempt = 0;
  Timer? _reconnectTimer;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final List<Map<String, dynamic>> _messageQueue = [];
  final List<Map<String, dynamic>> _typingQueue =
      []; // Queue for typing indicators

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
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Message> get onMessageReceived => _messageReceivedController.stream;
  Stream<Map<String, dynamic>> get onMatchFound => _matchFoundController.stream;
  Stream<String> get onWebRtcSignal => _webRtcSignalController.stream;
  Stream<ConnectionState> get onConnectionStateChanged =>
      _connectionStateController.stream;
  Stream<String> get onMatchRequestStatus =>
      _matchRequestStatusController.stream;
  Stream<String> get onError => _errorController.stream;

  Stream<Map<String, dynamic>> get onUserTyping => _typingController.stream;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get connectionId => _connectionId;
  int? get currentUserId => _currentUserId;
  String? get accessToken => _accessToken;
  int get queuedMessagesCount => _messageQueue.length;
  int get queuedTypingCount => _typingQueue.length;
  Set<String> get availableServerMethods => Set.from(_availableServerMethods);

  MessageHeaders _createMessageHeaders(Map<String, String> headers) {
    final messageHeaders = MessageHeaders();
    headers.forEach((key, value) {
      messageHeaders.setHeaderValue(key, value);
    });
    return messageHeaders;
  }

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

      _connectionStateController.add(ConnectionState.connecting);

      if (!await _hasNetworkConnection()) {
        log('No network connection available');
        _isConnecting = false;
        _connectionStateController.add(ConnectionState.disconnected);
        _errorController.add('No network connection available');
        return false;
      }

      final hubUrlWithUserId = '$_hubUrl?userId=$userId';

      _hubConnection = HubConnectionBuilder()
          .withUrl(hubUrlWithUserId,
              options: HttpConnectionOptions(
                accessTokenFactory: () => Future.value(accessToken),
                transport: HttpTransportType.WebSockets,
                skipNegotiation: false,
                requestTimeout: 30000,
                headers: _createMessageHeaders({
                  'Authorization': 'Bearer $accessToken',
                  'User-Agent': 'Flutter-SignalR-Client',
                }),
              ))
          .withAutomaticReconnect(
            retryDelays: [2000, 5000, 10000, 30000],
          )
          .configureLogging(Logger('SignalR'))
          .build();

      _setupEventHandlers();

      await _hubConnection!.start()!.timeout(
        Duration(seconds: _connectionTimeout),
        onTimeout: () {
          throw TimeoutException(
              'Connection timeout after $_connectionTimeout seconds');
        },
      );

      _isConnected = true;
      _isConnecting = false;
      _connectionId = _hubConnection!.connectionId;
      _retryAttempt = 0;

      log('SignalR connected successfully. Connection ID: $_connectionId');

      if (enableAutoReconnect) {
        _startConnectivityMonitoring();
      }

      await _processMessageQueue();
      await _processTypingQueue();

      _connectionStateController.add(ConnectionState.connected);
      return true;
    } catch (e) {
      log('SignalR connection failed: $e');
      _isConnected = false;
      _isConnecting = false;
      _connectionStateController.add(ConnectionState.disconnected);
      _errorController.add('Connection failed: $e');

      if (_retryAttempt < _maxRetryAttempts) {
        _scheduleReconnect();
      } else {
        _errorController
            .add('Max retry attempts reached. Please try again later.');
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
      _connectionStateController.add(ConnectionState.disconnected);

      if (error != null) {
        _errorController.add('Connection closed: $error');
      }

      _scheduleReconnect();
    });

    _hubConnection!.onreconnecting(({Exception? error}) {
      log('SignalR reconnecting: $error');
      _isConnected = false;
      _connectionStateController.add(ConnectionState.reconnecting);

      if (error != null) {
        _errorController.add('Reconnecting: $error');
      }
    });

    _hubConnection!.onreconnected(({String? connectionId}) {
      log('SignalR reconnected. New connection ID: $connectionId');
      _isConnected = true;
      _connectionId = connectionId;
      _retryAttempt = 0;
      _connectionStateController.add(ConnectionState.connected);
      _processMessageQueue();
      _processTypingQueue();
    });

    _hubConnection!.on('ReceiveMessage', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) {
          log('Received empty message arguments');
          return;
        }

        final messageData = arguments[0];
        log('Raw message data: $messageData');

        Map<String, dynamic> messageMap;
        if (messageData is Map<String, dynamic>) {
          messageMap = messageData;
        } else if (messageData is String) {
          messageMap = {
            'content': messageData,
            'timestamp': DateTime.now().toIso8601String()
          };
        } else {
          log('Unexpected message data type: ${messageData.runtimeType}');
          return;
        }

        final message = Message.fromJson(messageMap);
        _messageReceivedController.add(message);
        log('Message received: ${message.content}');
      } catch (e) {
        log('Error parsing received message: $e');
        _errorController.add('Error parsing message: $e');
      }
    });

    _hubConnection!.on('ReceiveTypingIndicator', (arguments) {
      try {
        if (arguments == null || arguments.length < 2) {
          log('Received invalid typing indicator arguments');
          return;
        }

        final userId = arguments[0];
        final isTyping = arguments[1];

        log('Typing indicator received - UserId: $userId, IsTyping: $isTyping');

        final typingData = {
          'userId':
              userId is int ? userId : int.tryParse(userId.toString()) ?? 0,
          'isTyping': isTyping is bool
              ? isTyping
              : (isTyping.toString().toLowerCase() == 'true'),
        };

        _typingController.add(typingData);
        log('Typing indicator processed for user ${typingData['userId']}: ${typingData['isTyping']}');
      } catch (e) {
        log('Error parsing typing indicator: $e');
        _errorController.add('Error parsing typing indicator: $e');
      }
    });

    _hubConnection!.on('MatchFound', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) {
          log('Received empty match arguments');
          return;
        }

        final matchData = arguments[0];
        log('Raw match data: $matchData');

        if (matchData is Map<String, dynamic>) {
          _matchFoundController.add(matchData);
          log('Match found: ${matchData['id']}');
        } else {
          log('Unexpected match data type: ${matchData.runtimeType}');
        }
      } catch (e) {
        log('Error parsing match found: $e');
        _errorController.add('Error parsing match: $e');
      }
    });

    _hubConnection!.on('ReceiveWebRtcSignal', (arguments) {
      try {
        if (arguments == null || arguments.length < 2) {
          log('Received incomplete WebRTC signal arguments');
          return;
        }

        final fromUserId = arguments[0]?.toString() ?? '';
        final signalData = arguments[1]?.toString() ?? '';

        if (signalData.isNotEmpty) {
          _webRtcSignalController.add(signalData);
          log('WebRTC signal received from user $fromUserId');
        }
      } catch (e) {
        log('Error parsing WebRTC signal: $e');
        _errorController.add('Error parsing WebRTC signal: $e');
      }
    });

    // Enhanced match request handlers
    _hubConnection!.on('MatchRequestReceived', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) return;
        final matchType = arguments[0]?.toString() ?? 'unknown';
        final message = 'Match request received for: $matchType';
        _matchRequestStatusController.add(message);
        log(message);
      } catch (e) {
        log('Error parsing match request confirmation: $e');
        _errorController.add('Error parsing match request: $e');
      }
    });

    _hubConnection!.on('MatchRequestError', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) return;
        final error = arguments[0]?.toString() ?? 'Unknown error';
        final message = 'Match request error: $error';
        _matchRequestStatusController.add(message);
        _errorController.add(message);
        log(message);
      } catch (e) {
        log('Error parsing match request error: $e');
      }
    });

    _hubConnection!.on('MatchRequestSuccess', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) return;
        final message = 'Match request successful: ${arguments[0]}';
        _matchRequestStatusController.add(message);
        log(message);
      } catch (e) {
        log('Error parsing match request success: $e');
      }
    });

    _hubConnection!.on('QueueJoined', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) return;
        final queueInfo = arguments[0]?.toString() ?? 'Unknown queue';
        final message = 'Joined queue: $queueInfo';
        _matchRequestStatusController.add(message);
        log(message);
      } catch (e) {
        log('Error parsing queue joined: $e');
      }
    });

    _hubConnection!.on('Error', (arguments) {
      try {
        if (arguments == null || arguments.isEmpty) return;
        final error = arguments[0]?.toString() ?? 'Unknown error';
        _errorController.add('Server error: $error');
        log('Server error: $error');
      } catch (e) {
        log('Error parsing server error: $e');
      }
    });
  }

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

    if (!_isConnected) {
      _messageQueue.add(messageData);
      log('Message queued for later sending (offline)');
      return false;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _hubConnection!.invoke('SendMessageAsync', args: [
          receiverId,
          content,
        ]).timeout(const Duration(seconds: 15));

        log('Message sent successfully to user $receiverId');
        return true;
      } catch (e) {
        log('Error sending message (attempt $attempt/$maxRetries): $e');

        if (attempt < maxRetries) {
          final delay = Duration(seconds: attempt * 2);
          await Future.delayed(delay);
        } else {
          _messageQueue.add(messageData);
          _errorController
              .add('Failed to send message after $maxRetries attempts');
          log('Message queued after all retry attempts failed');
        }
      }
    }

    return false;
  }

  Future<bool> sendTypingIndicator({
    required int receiverId,
    required bool isTyping,
    int maxRetries = 2,
  }) async {
    final typingData = {
      'receiverId': receiverId,
      'isTyping': isTyping,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (!_isConnected) {
      if (isTyping) {
        _typingQueue.add(typingData);
        log('Typing indicator queued for later sending (offline)');
      }
      return false;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _hubConnection!.invoke('SendTypingIndicator', args: [
          receiverId,
          isTyping,
        ]).timeout(const Duration(seconds: 10));

        log('Typing indicator sent successfully to user $receiverId: $isTyping');
        return true;
      } catch (e) {
        log('Error sending typing indicator (attempt $attempt/$maxRetries): $e');

        if (attempt < maxRetries) {
          final delay = Duration(milliseconds: 500 * attempt);
          await Future.delayed(delay);
        } else {
          if (isTyping) {
            _typingQueue.add(typingData);
          }
          _errorController.add(
              'Failed to send typing indicator after $maxRetries attempts');
          log('Typing indicator queued after all retry attempts failed');
        }
      }
    }

    return false;
  }

  Future<bool> requestMatch(String matchType) async {
    try {
      if (!_isConnected || _hubConnection == null) {
        _errorController.add('SignalR not connected');
        log('SignalR not connected, cannot request match');
        return false;
      }

      log('Requesting match for type: $matchType');

      await _hubConnection!.invoke(
        'RequestMatchAsync',
        args: [matchType],
      ).timeout(
        const Duration(seconds: 15),
      );

      log('Match request sent successfully');
      return true;
    } catch (e) {
      final errorMessage = 'Match request failed: $e';
      log(errorMessage);
      _errorController.add(errorMessage);
      _matchRequestStatusController.add(errorMessage);
      return false;
    }
  }

  /// Send WebRTC signal with error handling
  Future<bool> sendWebRtcSignal({
    required String targetUserId,
    required String signalData,
  }) async {
    try {
      if (!_isConnected || _hubConnection == null) {
        _errorController.add('SignalR not connected for WebRTC signal');
        return false;
      }

      await _hubConnection!.invoke('SendWebRtcSignal', args: [
        targetUserId,
        signalData,
      ]).timeout(const Duration(seconds: 10));

      log('WebRTC signal sent to user $targetUserId');
      return true;
    } catch (e) {
      final errorMessage = 'Error sending WebRTC signal: $e';
      log(errorMessage);
      _errorController.add(errorMessage);
      return false;
    }
  }

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

  Future<void> _processTypingQueue() async {
    if (_typingQueue.isEmpty || !_isConnected) return;

    final typingToProcess = List<Map<String, dynamic>>.from(_typingQueue);
    _typingQueue.clear();

    for (final typingData in typingToProcess) {
      try {
        if (typingData['isTyping'] == true) {
          await sendTypingIndicator(
            receiverId: typingData['receiverId'],
            isTyping: typingData['isTyping'],
            maxRetries: 1,
          );
        }
      } catch (e) {
        log('Error processing queued typing indicator: $e');
      }
    }

    log('Processed ${typingToProcess.length} queued typing indicators');
  }

  /// Test connection with server
  Future<bool> testConnection() async {
    try {
      if (!_isConnected || _hubConnection == null) return false;

      final state = _hubConnection!.state;
      final isConnected = state == HubConnectionState.Connected;

      log('Connection test - State: $state, Connected: $isConnected');
      return isConnected;
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

      log('Connectivity changed: $result');

      if (result != ConnectivityResult.none &&
          !_isConnected &&
          !_isConnecting) {
        log('Network connectivity restored, attempting reconnect...');
        _attemptReconnect();
      } else if (result == ConnectivityResult.none && _isConnected) {
        log('Network connectivity lost');
        _errorController.add('Network connectivity lost');
      }
    });
  }

  Future<bool> _hasNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      log('Network check failed: $e');
      return false;
    }
  }

  void _scheduleReconnect() {
    if (_retryAttempt >= _maxRetryAttempts) {
      log('Max retry attempts reached. Stopping reconnect attempts.');
      _errorController
          .add('Max retry attempts reached. Please try again later.');
      return;
    }

    _reconnectTimer?.cancel();
    final delay = _reconnectDelay * (1 << _retryAttempt); // Exponential backoff

    log('Scheduling reconnect in ${delay}ms (attempt ${_retryAttempt + 1}/$_maxRetryAttempts)');

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

  void dispose() {
    _messageReceivedController.close();
    _matchFoundController.close();
    _webRtcSignalController.close();
    _connectionStateController.close();
    _matchRequestStatusController.close();
    _errorController.close();
    _typingController.close();
    _messageQueue.clear();
    _typingQueue.clear();
    disconnect();
  }

  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': _isConnected,
      'isConnecting': _isConnecting,
      'connectionId': _connectionId,
      'retryAttempt': _retryAttempt,
      'maxRetryAttempts': _maxRetryAttempts,
      'queuedMessages': _messageQueue.length,
      'queuedTypingIndicators': _typingQueue.length,
      'currentUserId': _currentUserId,
      'availableServerMethods': _availableServerMethods.toList(),
      'hubConnectionState': _hubConnection?.state.toString(),
    };
  }
}

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  waiting,
}
