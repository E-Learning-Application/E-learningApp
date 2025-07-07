import 'dart:async';
import 'dart:developer';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:e_learning_app/core/model/message_model.dart';

class SignalRService {
  static const String _hubUrl =
      'https://elearningproject.runasp.net/messageHub';

  HubConnection? _hubConnection;
  bool _isConnected = false;
  String? _connectionId;
  int? _currentUserId;
  String? _accessToken;

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

  // Public streams
  Stream<Message> get onMessageReceived => _messageReceivedController.stream;
  Stream<Map<String, dynamic>> get onMessageStatusUpdated =>
      _messageStatusUpdatedController.stream;
  Stream<Map<String, dynamic>> get onUserOnlineStatusChanged =>
      _userOnlineStatusChangedController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;
  Stream<Map<String, dynamic>> get onMatchFound => _matchFoundController.stream;
  Stream<Map<String, dynamic>> get onMatchEnded => _matchEndedController.stream;

  // Getters
  bool get isConnected => _isConnected;
  String? get connectionId => _connectionId;
  int? get currentUserId => _currentUserId;

  // Initialize SignalR connection
  Future<bool> initialize({
    required int userId,
    required String accessToken,
  }) async {
    try {
      _currentUserId = userId;
      _accessToken = accessToken;

      // Create hub connection
      _hubConnection = HubConnectionBuilder()
          .withUrl(_hubUrl,
              options: HttpConnectionOptions(
                accessTokenFactory: () => Future.value(accessToken),
                transport: HttpTransportType.WebSockets,
                skipNegotiation: true,
              ))
          .withAutomaticReconnect()
          .build();

      // Set up event handlers
      _setupEventHandlers();

      // Start connection
      await _hubConnection!.start();

      _isConnected = true;
      _connectionId = _hubConnection!.connectionId;

      log('SignalR connected successfully. Connection ID: $_connectionId');

      // Join user to their personal group
      await _joinUserGroup(userId);

      return true;
    } catch (e) {
      log('SignalR connection failed: $e');
      _isConnected = false;
      return false;
    }
  }

  void _setupEventHandlers() {
    if (_hubConnection == null) return;

    // Added cast to handel error
    _hubConnection!.onclose((Exception? error) {
      log('SignalR connection closed: $error');
      _isConnected = false;
      _connectionId = null;
    } as ClosedCallback);

    _hubConnection!.onreconnecting((Exception? error) {
      log('SignalR reconnecting: $error');
      _isConnected = false;
    } as ReconnectingCallback);

    _hubConnection!.onreconnected((String? connectionId) {
      log('SignalR reconnected. New connection ID: $connectionId');
      _isConnected = true;
      _connectionId = connectionId;

      if (_currentUserId != null) {
        _joinUserGroup(_currentUserId!);
      }
    } as ReconnectedCallback);

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
        });
        log('Match ended: $matchId, reason: $reason');
      } catch (e) {
        log('Error parsing match ended: $e');
      }
    });
  }

  Future<void> _joinUserGroup(int userId) async {
    try {
      await _hubConnection?.invoke('JoinUserGroup', args: [userId]);
      log('Joined user group: $userId');
    } catch (e) {
      log('Error joining user group: $e');
    }
  }

  Future<bool> sendMessage({
    required int receiverId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      if (!_isConnected || _hubConnection == null) {
        log('SignalR not connected, cannot send message');
        return false;
      }

      await _hubConnection!.invoke('SendMessage', args: [
        receiverId,
        content,
        messageType,
      ]);

      log('Message sent to user $receiverId: $content');
      return true;
    } catch (e) {
      log('Error sending message: $e');
      return false;
    }
  }

  Future<void> sendTypingIndicator({
    required int receiverId,
    required bool isTyping,
  }) async {
    try {
      if (!_isConnected || _hubConnection == null) return;

      await _hubConnection!.invoke('SendTypingIndicator', args: [
        receiverId,
        isTyping,
      ]);

      log('Typing indicator sent to user $receiverId: $isTyping');
    } catch (e) {
      log('Error sending typing indicator: $e');
    }
  }

  Future<void> markMessageAsRead(int messageId) async {
    try {
      if (!_isConnected || _hubConnection == null) return;

      await _hubConnection!.invoke('MarkMessageAsRead', args: [messageId]);
      log('Message marked as read: $messageId');
    } catch (e) {
      log('Error marking message as read: $e');
    }
  }

  Future<void> setOnlineStatus(bool isOnline) async {
    try {
      if (!_isConnected || _hubConnection == null) return;

      await _hubConnection!.invoke('SetOnlineStatus', args: [isOnline]);
      log('Online status set to: $isOnline');
    } catch (e) {
      log('Error setting online status: $e');
    }
  }

  Future<void> joinMatchRoom(int matchId) async {
    try {
      if (!_isConnected || _hubConnection == null) return;

      await _hubConnection!.invoke('JoinMatchRoom', args: [matchId]);
      log('Joined match room: $matchId');
    } catch (e) {
      log('Error joining match room: $e');
    }
  }

  Future<void> leaveMatchRoom(int matchId) async {
    try {
      if (!_isConnected || _hubConnection == null) return;

      await _hubConnection!.invoke('LeaveMatchRoom', args: [matchId]);
      log('Left match room: $matchId');
    } catch (e) {
      log('Error leaving match room: $e');
    }
  }

  Future<void> requestMatch(String matchType) async {
    try {
      if (!_isConnected || _hubConnection == null) return;

      await _hubConnection!.invoke('RequestMatch', args: [matchType]);
      log('Match requested: $matchType');
    } catch (e) {
      log('Error requesting match: $e');
    }
  }

  Future<void> cancelMatchRequest() async {
    try {
      if (!_isConnected || _hubConnection == null) return;

      await _hubConnection!.invoke('CancelMatchRequest');
      log('Match request cancelled');
    } catch (e) {
      log('Error cancelling match request: $e');
    }
  }

  Future<void> endMatch(int matchId) async {
    try {
      if (!_isConnected || _hubConnection == null) return;

      await _hubConnection!.invoke('EndMatch', args: [matchId]);
      log('Match ended: $matchId');
    } catch (e) {
      log('Error ending match: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      if (_hubConnection != null) {
        await _hubConnection!.stop();
        _isConnected = false;
        _connectionId = null;
        log('SignalR disconnected');
      }
    } catch (e) {
      log('Error disconnecting SignalR: $e');
    }
  }

  void dispose() {
    _messageReceivedController.close();
    _messageStatusUpdatedController.close();
    _userOnlineStatusChangedController.close();
    _userTypingController.close();
    _matchFoundController.close();
    _matchEndedController.close();

    disconnect();
  }
}

extension SignalRServiceExtension on SignalRService {
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
}
