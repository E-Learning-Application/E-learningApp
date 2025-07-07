import 'dart:async';
import 'dart:developer';
import 'package:e_learning_app/core/service/message_service.dart';
import 'package:e_learning_app/core/service/signalr_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/core/model/message_model.dart';
import 'message_state.dart';

class MessageCubit extends Cubit<MessageState> {
  final MessageService _messageService;
  final SignalRService _signalRService;

  // Internal state management
  final Map<int, List<MessageWithStatus>> _chatMessages = {};
  final Map<int, StreamSubscription> _chatSubscriptions = {};
  final Map<int, bool> _userTypingStatus = {};
  List<ChatSummary> _chatList = [];
  int _totalUnreadCount = 0;
  int? _currentChatUserId;
  Timer? _typingTimer;

  MessageCubit({
    required MessageService messageService,
    required SignalRService signalRService,
  })  : _messageService = messageService,
        _signalRService = signalRService,
        super(MessageInitial()) {
    _initializeSignalRListeners();
  }

  void _initializeSignalRListeners() {
    // Listen for new messages
    _signalRService.onMessageReceived.listen((message) {
      _handleNewMessage(message);
    });

    // Listen for message status updates
    _signalRService.onMessageStatusUpdated.listen((data) {
      _handleMessageStatusUpdate(data['messageId'], data['status']);
    });

    // Listen for user online status changes
    _signalRService.onUserOnlineStatusChanged.listen((data) {
      _handleUserOnlineStatusChange(data['userId'], data['isOnline']);
    });

    // Listen for typing indicators
    _signalRService.onUserTyping.listen((data) {
      _handleTypingIndicator(data['userId'], data['isTyping']);
    });

    // Listen for match events
    _signalRService.onMatchFound.listen((data) {
      _handleMatchFound(data);
    });

    _signalRService.onMatchEnded.listen((data) {
      _handleMatchEnded(data);
    });
  }

  // Load chat list
  Future<void> loadChatList() async {
    try {
      emit(MessageLoading());

      final chats = await _messageService.getChatList();
      final unreadCount = await _messageService.getUnreadCount();

      _chatList = chats;
      _totalUnreadCount = unreadCount;

      if (chats.isEmpty) {
        emit(ChatListEmpty());
      } else {
        emit(ChatListLoaded(
          chats: chats,
          totalUnreadCount: unreadCount,
        ));
      }
    } catch (e) {
      log('Error loading chat list: $e');
      emit(MessageError(message: 'Failed to load chats: $e'));
    }
  }

  // Load specific chat
  Future<void> loadChat(int otherUserId, String otherUserName) async {
    try {
      emit(MessageLoading());

      final messages = await _messageService.getChatWith(otherUserId);
      final messagesWithStatus = messages
          .map((msg) => MessageWithStatus(
                message: msg,
                status:
                    msg.isRead ? MessageStatus.read : MessageStatus.delivered,
              ))
          .toList();

      _chatMessages[otherUserId] = messagesWithStatus;
      _currentChatUserId = otherUserId;

      // Find user online status from chat list
      final chatSummary = _chatList.firstWhere(
        (chat) => chat.userId == otherUserId,
        orElse: () => ChatSummary(
          userId: otherUserId,
          userName: otherUserName,
          lastMessage: '',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
          isOnline: false,
        ),
      );

      if (messages.isEmpty) {
        emit(ChatEmpty(
          otherUserId: otherUserId,
          otherUserName: otherUserName,
        ));
      } else {
        emit(ChatLoaded(
          messages: messagesWithStatus,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          isOtherUserOnline: chatSummary.isOnline,
        ));
      }

      // Mark messages as read
      await _markChatMessagesAsRead(otherUserId);
    } catch (e) {
      log('Error loading chat with user $otherUserId: $e');
      emit(MessageError(message: 'Failed to load chat: $e'));
    }
  }

  // Send message
  Future<void> sendMessage(int receiverId, String content,
      {String messageType = 'text'}) async {
    try {
      // Create temporary message with sending status
      final tempMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
        senderId: _signalRService.currentUserId ?? 0,
        receiverId: receiverId,
        content: content,
        timestamp: DateTime.now(),
        isRead: false,
        messageType: messageType,
      );

      final messageWithStatus = MessageWithStatus(
        message: tempMessage,
        status: MessageStatus.sending,
      );

      // Add to local state immediately
      _addMessageToChat(receiverId, messageWithStatus);
      emit(MessageSending(message: messageWithStatus));

      // Send via SignalR
      final success = await _signalRService.sendMessage(
        receiverId: receiverId,
        content: content,
        messageType: messageType,
      );

      if (success) {
        // Update message status to sent
        _updateMessageStatus(tempMessage.id, MessageStatus.sent);
        emit(MessageSent(message: tempMessage));

        // Refresh current chat if viewing this conversation
        if (_currentChatUserId == receiverId) {
          await _refreshCurrentChat();
        }
      } else {
        // Update message status to failed
        _updateMessageStatus(tempMessage.id, MessageStatus.failed);
        emit(MessageSendFailed(
          content: content,
          errorMessage: 'Failed to send message',
        ));
      }
    } catch (e) {
      log('Error sending message: $e');
      emit(MessageSendFailed(
        content: content,
        errorMessage: 'Failed to send message: $e',
      ));
    }
  }

  // Send typing indicator
  Future<void> sendTypingIndicator(int receiverId, bool isTyping) async {
    try {
      await _signalRService.sendTypingIndicator(
        receiverId: receiverId,
        isTyping: isTyping,
      );

      // Auto-stop typing after 3 seconds
      if (isTyping) {
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          sendTypingIndicator(receiverId, false);
        });
      } else {
        _typingTimer?.cancel();
      }
    } catch (e) {
      log('Error sending typing indicator: $e');
    }
  }

  // Mark message as read
  Future<void> markMessageAsRead(int messageId) async {
    try {
      final success = await _messageService.markMessageAsRead(messageId);
      if (success) {
        // Also notify via SignalR
        await _signalRService.markMessageAsRead(messageId);

        emit(MessageMarkedAsRead(messageId: messageId));
        await _updateUnreadCount();
      }
    } catch (e) {
      log('Error marking message as read: $e');
    }
  }

  // Delete message
  Future<void> deleteMessage(int messageId) async {
    try {
      final success = await _messageService.deleteMessage(messageId);
      if (success) {
        _removeMessageFromChats(messageId);
        emit(MessageDeleted(messageId: messageId));
        emit(MessageOperationSuccess(
          message: 'Message deleted successfully',
          actionType: 'delete',
        ));

        // Refresh current chat
        if (_currentChatUserId != null) {
          await _refreshCurrentChat();
        }
      } else {
        emit(MessageError(message: 'Failed to delete message'));
      }
    } catch (e) {
      log('Error deleting message: $e');
      emit(MessageError(message: 'Failed to delete message: $e'));
    }
  }

  // Get unread count
  Future<void> updateUnreadCount() async {
    await _updateUnreadCount();
  }

  // Refresh current chat
  Future<void> refreshCurrentChat() async {
    if (_currentChatUserId != null) {
      await _refreshCurrentChat();
    }
  }

  // Clear current chat
  void clearCurrentChat() {
    _currentChatUserId = null;
    _userTypingStatus.clear();
    _typingTimer?.cancel();
  }

  // Get typing status for user
  bool isUserTyping(int userId) {
    return _userTypingStatus[userId] ?? false;
  }

  // Private helper methods
  void _handleNewMessage(Message message) {
    // Add to appropriate chat
    final otherUserId = message.senderId == _signalRService.currentUserId
        ? message.receiverId
        : message.senderId;

    final messageWithStatus = MessageWithStatus(
      message: message,
      status: MessageStatus.delivered,
    );

    _addMessageToChat(otherUserId, messageWithStatus);

    // Update chat list
    _updateChatListWithNewMessage(message);

    // Auto-mark as read if currently viewing this chat
    if (_currentChatUserId == otherUserId &&
        message.receiverId == _signalRService.currentUserId) {
      markMessageAsRead(message.id);
    }

    emit(NewMessageReceived(message: message));
  }

  void _handleMessageStatusUpdate(int messageId, String status) {
    MessageStatus messageStatus;
    switch (status.toLowerCase()) {
      case 'sent':
        messageStatus = MessageStatus.sent;
        break;
      case 'delivered':
        messageStatus = MessageStatus.delivered;
        break;
      case 'read':
        messageStatus = MessageStatus.read;
        break;
      default:
        messageStatus = MessageStatus.delivered;
    }

    _updateMessageStatus(messageId, messageStatus);
    emit(MessageStatusUpdated(messageId: messageId, status: messageStatus));
  }

  void _handleUserOnlineStatusChange(int userId, bool isOnline) {
    // Update chat list
    final chatIndex = _chatList.indexWhere((chat) => chat.userId == userId);
    if (chatIndex != -1) {
      _chatList[chatIndex] = ChatSummary(
        userId: _chatList[chatIndex].userId,
        userName: _chatList[chatIndex].userName,
        profileImage: _chatList[chatIndex].profileImage,
        lastMessage: _chatList[chatIndex].lastMessage,
        lastMessageTime: _chatList[chatIndex].lastMessageTime,
        unreadCount: _chatList[chatIndex].unreadCount,
        isOnline: isOnline,
      );
    }

    emit(UserOnlineStatusChanged(userId: userId, isOnline: isOnline));
  }

  void _handleTypingIndicator(int userId, bool isTyping) {
    _userTypingStatus[userId] = isTyping;

    // Auto-clear typing status after 5 seconds
    if (isTyping) {
      Timer(const Duration(seconds: 5), () {
        _userTypingStatus[userId] = false;
      });
    }

    // Emit typing status if currently viewing this chat
    if (_currentChatUserId == userId) {
      emit(UserOnlineStatusChanged(
          userId: userId, isOnline: isUserTyping(userId)));
    }
  }

  void _handleMatchFound(Map<String, dynamic> matchData) {
    // Handle match found event
    emit(MessageOperationSuccess(
      message: 'Match found! You can now start chatting.',
      actionType: 'match_found',
    ));
  }

  void _handleMatchEnded(Map<String, dynamic> data) {
    final matchId = data['matchId'] as int;
    final reason = data['reason'] as String?;

    emit(MessageOperationSuccess(
      message: 'Match ended${reason != null ? ': $reason' : ''}',
      actionType: 'match_ended',
    ));
  }

  void _addMessageToChat(int otherUserId, MessageWithStatus messageWithStatus) {
    if (!_chatMessages.containsKey(otherUserId)) {
      _chatMessages[otherUserId] = [];
    }
    _chatMessages[otherUserId]!.add(messageWithStatus);
  }

  void _updateMessageStatus(int messageId, MessageStatus status) {
    _chatMessages.forEach((userId, messages) {
      final messageIndex =
          messages.indexWhere((msg) => msg.message.id == messageId);
      if (messageIndex != -1) {
        _chatMessages[userId]![messageIndex] =
            messages[messageIndex].copyWith(status: status);
      }
    });
  }

  void _removeMessageFromChats(int messageId) {
    _chatMessages.forEach((userId, messages) {
      messages.removeWhere((msg) => msg.message.id == messageId);
    });
  }

  void _updateChatListWithNewMessage(Message message) {
    final otherUserId = message.senderId == _signalRService.currentUserId
        ? message.receiverId
        : message.senderId;

    final chatIndex =
        _chatList.indexWhere((chat) => chat.userId == otherUserId);
    if (chatIndex != -1) {
      final existingChat = _chatList[chatIndex];
      _chatList[chatIndex] = ChatSummary(
        userId: existingChat.userId,
        userName: existingChat.userName,
        profileImage: existingChat.profileImage,
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
        unreadCount: existingChat.unreadCount +
            (message.senderId != _signalRService.currentUserId ? 1 : 0),
        isOnline: existingChat.isOnline,
      );
    }
  }

  Future<void> _markChatMessagesAsRead(int otherUserId) async {
    final messages = _chatMessages[otherUserId] ?? [];
    for (final messageWithStatus in messages) {
      if (!messageWithStatus.message.isRead &&
          messageWithStatus.message.receiverId ==
              _signalRService.currentUserId) {
        await markMessageAsRead(messageWithStatus.message.id);
      }
    }
  }

  Future<void> _updateUnreadCount() async {
    try {
      final count = await _messageService.getUnreadCount();
      _totalUnreadCount = count;
      emit(UnreadCountUpdated(count: count));
    } catch (e) {
      log('Error updating unread count: $e');
    }
  }

  Future<void> _refreshCurrentChat() async {
    if (_currentChatUserId == null) return;

    try {
      final messages = await _messageService.getChatWith(_currentChatUserId!);
      final messagesWithStatus = messages
          .map((msg) => MessageWithStatus(
                message: msg,
                status:
                    msg.isRead ? MessageStatus.read : MessageStatus.delivered,
              ))
          .toList();

      _chatMessages[_currentChatUserId!] = messagesWithStatus;

      final chatSummary = _chatList.firstWhere(
        (chat) => chat.userId == _currentChatUserId!,
        orElse: () => ChatSummary(
          userId: _currentChatUserId!,
          userName: 'Unknown',
          lastMessage: '',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
          isOnline: false,
        ),
      );

      if (messages.isEmpty) {
        emit(ChatEmpty(
          otherUserId: _currentChatUserId!,
          otherUserName: chatSummary.userName,
        ));
      } else {
        emit(ChatLoaded(
          messages: messagesWithStatus,
          otherUserId: _currentChatUserId!,
          otherUserName: chatSummary.userName,
          isOtherUserOnline: chatSummary.isOnline,
        ));
      }
    } catch (e) {
      log('Error refreshing current chat: $e');
    }
  }

  @override
  Future<void> close() {
    _chatSubscriptions.values.forEach((subscription) => subscription.cancel());
    _chatSubscriptions.clear();
    _typingTimer?.cancel();
    _chatMessages.clear();
    _chatList.clear();
    _userTypingStatus.clear();
    _currentChatUserId = null;

    return super.close();
  }
}
