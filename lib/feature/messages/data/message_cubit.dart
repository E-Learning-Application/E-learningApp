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

    // Listen for match events
    _signalRService.onMatchFound.listen((data) {
      _handleMatchFound(data);
    });

    _signalRService.onWebRtcSignal.listen((signal) {
      // Handle WebRTC signal if needed
      log('WebRTC signal received: $signal');
    });
  }

  // Load chat list
  Future<void> loadChatList() async {
    try {
      emit(MessageLoading());

      final chats = await _messageService.getChatList();
      final unreadCount = await _getUnreadCount();

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

      final messages = await _messageService.getChatHistory(
        withUserId: otherUserId,
        page: 1,
        pageSize: 50,
      );

      final messagesWithStatus = messages
          .map((msg) => MessageWithStatus(
                message: msg,
                status: _getMessageStatusFromMessage(msg),
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

      final signalRSuccess = await _signalRService.sendMessage(
        receiverId: receiverId,
        content: content,
      );

      if (signalRSuccess) {
        // Update message status to sent
        _updateMessageStatus(tempMessage.id, MessageStatus.sent);
        emit(MessageSent(message: tempMessage));
      } else {
        // Fallback to REST API
        final sendRequest = SendMessageRequest(
          receiverId: receiverId,
          content: content,
          messageType: messageType,
        );

        final sentMessage = await _messageService.sendMessage(sendRequest);

        if (sentMessage != null) {
          // Replace temporary message with actual message
          _removeMessageFromChat(receiverId, tempMessage.id);
          _addMessageToChat(
              receiverId,
              MessageWithStatus(
                message: sentMessage,
                status: MessageStatus.sent,
              ));
          emit(MessageSent(message: sentMessage));
        } else {
          _updateMessageStatus(tempMessage.id, MessageStatus.failed);
          emit(MessageSendFailed(
            content: content,
            errorMessage: 'Failed to send message',
          ));
        }
      }

      // Refresh current chat if viewing this conversation
      if (_currentChatUserId == receiverId) {
        await _refreshCurrentChat();
      }
    } catch (e) {
      log('Error sending message: $e');
      emit(MessageSendFailed(
        content: content,
        errorMessage: 'Failed to send message: $e',
      ));
    }
  }

  Future<void> sendTypingIndicator(int receiverId, bool isTyping) async {
    try {
      _userTypingStatus[receiverId] = isTyping;

      // Auto-stop typing after 3 seconds
      if (isTyping) {
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          _userTypingStatus[receiverId] = false;
        });
      } else {
        _typingTimer?.cancel();
      }

      log('Typing indicator: User $receiverId is ${isTyping ? 'typing' : 'not typing'}');
    } catch (e) {
      log('Error sending typing indicator: $e');
    }
  }

  // Mark message as read
  Future<void> markMessageAsRead(int messageId) async {
    try {
      final success = await _messageService.markMessageAsRead(messageId);
      if (success) {
        _updateMessageStatus(messageId, MessageStatus.read);
        emit(MessageMarkedAsRead(messageId: messageId));
        await _updateUnreadCount();
      }
    } catch (e) {
      log('Error marking message as read: $e');
    }
  }

  // Mark all messages as read with a user
  Future<void> markAllMessagesAsRead(int withUserId) async {
    try {
      final success = await _messageService.markAllMessagesAsRead(withUserId);
      if (success) {
        // Update local state
        final messages = _chatMessages[withUserId] ?? [];
        for (int i = 0; i < messages.length; i++) {
          if (messages[i].message.receiverId == _signalRService.currentUserId) {
            _chatMessages[withUserId]![i] = messages[i].copyWith(
              status: MessageStatus.read,
            );
          }
        }

        emit(MessageOperationSuccess(
          message: 'All messages marked as read',
          actionType: 'mark_all_read',
        ));
        await _updateUnreadCount();
      }
    } catch (e) {
      log('Error marking all messages as read: $e');
      emit(MessageError(message: 'Failed to mark messages as read: $e'));
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

  // Search messages
  Future<void> searchMessages(String query) async {
    try {
      emit(MessageLoading());
      final messages = await _messageService.searchMessages(query);

      emit(MessageOperationSuccess(
        message: 'Found ${messages.length} messages',
        actionType: 'search',
      ));

      // You might want to create a specific state for search results
      // emit(SearchResultsLoaded(messages: messages));
    } catch (e) {
      log('Error searching messages: $e');
      emit(MessageError(message: 'Failed to search messages: $e'));
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

  // Request match
  Future<void> requestMatch(String matchType) async {
    try {
      final success = await _signalRService.requestMatch(matchType);
      if (success) {
        emit(MessageOperationSuccess(
          message: 'Match request sent',
          actionType: 'match_request',
        ));
      } else {
        emit(MessageError(message: 'Failed to request match'));
      }
    } catch (e) {
      log('Error requesting match: $e');
      emit(MessageError(message: 'Failed to request match: $e'));
    }
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

  void _handleMatchFound(Map<String, dynamic> matchData) {
    // Handle match found event
    emit(MessageOperationSuccess(
      message: 'Match found! You can now start chatting.',
      actionType: 'match_found',
    ));
  }

  void _addMessageToChat(int otherUserId, MessageWithStatus messageWithStatus) {
    if (!_chatMessages.containsKey(otherUserId)) {
      _chatMessages[otherUserId] = [];
    }
    _chatMessages[otherUserId]!.add(messageWithStatus);
  }

  void _removeMessageFromChat(int userId, int messageId) {
    if (_chatMessages.containsKey(userId)) {
      _chatMessages[userId]!.removeWhere((msg) => msg.message.id == messageId);
    }
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

  Future<int> _getUnreadCount() async {
    try {
      // Calculate unread count from chat list
      int count = 0;
      for (final chat in _chatList) {
        count += chat.unreadCount;
      }
      return count;
    } catch (e) {
      log('Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> _updateUnreadCount() async {
    try {
      final count = await _getUnreadCount();
      _totalUnreadCount = count;
      emit(UnreadCountUpdated(count: count));
    } catch (e) {
      log('Error updating unread count: $e');
    }
  }

  Future<void> _refreshCurrentChat() async {
    if (_currentChatUserId == null) return;

    try {
      final messages = await _messageService.getChatHistory(
        withUserId: _currentChatUserId!,
        page: 1,
        pageSize: 50,
      );

      final messagesWithStatus = messages
          .map((msg) => MessageWithStatus(
                message: msg,
                status: _getMessageStatusFromMessage(msg),
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

  MessageStatus _getMessageStatusFromMessage(Message message) {
    if (message.isRead) return MessageStatus.read;
    // You might want to add more logic here based on your Message model
    return MessageStatus.delivered;
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
