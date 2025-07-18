import 'package:e_learning_app/feature/messages/data/message_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/core/model/message_model.dart'
    hide MessageWithStatus, MessageStatus;
import 'package:e_learning_app/core/service/message_service.dart';
import 'package:e_learning_app/core/service/signalr_service.dart' as signalr;
import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';

class MessageCubit extends Cubit<MessageState> {
  final MessageService _messageService;
  final signalr.SignalRService _signalRService;

  final Map<int, Timer?> _typingTimers = {};
  final Map<int, bool> _isTypingMap = {};
  final Map<int, DateTime> _lastTypingTime = {};

  static const Duration _typingTimeout = Duration(seconds: 3);
  static const Duration _typingDebounce = Duration(milliseconds: 500);

  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  final Map<int, StreamController<List<MessageWithStatus>>> _chatStreams = {};
  final Map<int, List<MessageWithStatus>> _chatMessages = {};

  MessageCubit({
    required MessageService messageService,
    required signalr.SignalRService signalRService,
  })  : _messageService = messageService,
        _signalRService = signalRService,
        super(MessageInitial()) {
    _setupListeners();
  }

  void _setupListeners() {
    _messageSubscription = _signalRService.onMessageReceived.listen((message) {
      _handleNewMessage(message);
    });

    _typingSubscription = _signalRService.onUserTyping.listen((typingData) {
      _handleTypingIndicator(typingData);
    });
  }

  Stream<List<MessageWithStatus>> getChatStream(int withUserId) {
    if (!_chatStreams.containsKey(withUserId)) {
      _chatStreams[withUserId] =
          StreamController<List<MessageWithStatus>>.broadcast();
      _chatMessages[withUserId] = [];
    }
    return _chatStreams[withUserId]!.stream;
  }

  void _updateChatMessages(int withUserId, List<MessageWithStatus> messages) {
    _chatMessages[withUserId] = messages;
    _chatStreams[withUserId]?.add(messages);
  }

  Future<void> loadChatList() async {
    try {
      emit(MessageLoading());

      final chats = await _messageService.getChatList();
      final totalUnreadCount = chats.fold<int>(
        0,
        (sum, chat) => sum + (chat.unreadCount ?? 0),
      );

      if (chats.isEmpty) {
        emit(ChatListEmpty());
      } else {
        emit(ChatListLoaded(
          chats: chats,
          totalUnreadCount: totalUnreadCount,
        ));
      }
    } catch (e) {
      log('Error loading chat list: $e');
      emit(MessageError(message: 'Failed to load chats: $e'));
    }
  }

  Future<void> loadAllMessages() async {
    try {
      emit(MessageLoading());

      final messages = await _messageService.getAllMessages();

      final messagesWithStatus = messages
          .map((msg) => MessageWithStatus(
                message: msg,
                status: MessageStatus.sent,
                isDelivered: true,
                isRead: msg.isRead,
              ))
          .toList();

      if (messages.isEmpty) {
        emit(MessageError(message: 'No messages found'));
      } else {
        emit(AllMessagesLoaded(messages: messagesWithStatus));
      }
    } catch (e) {
      log('Error loading all messages: $e');
      emit(MessageError(message: 'Failed to load all messages: $e'));
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      final count = await _messageService.getUnreadCount();
      emit(UnreadCountUpdated(count: count));
    } catch (e) {
      log('Error loading unread count: $e');
      emit(MessageError(message: 'Failed to load unread count: $e'));
    }
  }

  Future<void> loadLastMessageWith(int userId) async {
    try {
      final message = await _messageService.getLastMessageWith(userId);

      if (message != null) {
        emit(LastMessageLoaded(
          message: MessageWithStatus(
            message: message,
            status: MessageStatus.sent,
            isDelivered: true,
            isRead: message.isRead,
          ),
          withUserId: userId,
        ));
      } else {
        emit(MessageError(message: 'No messages found with user $userId'));
      }
    } catch (e) {
      log('Error loading last message with user $userId: $e');
      emit(MessageError(message: 'Failed to load last message: $e'));
    }
  }

  Future<void> loadPaginatedMessages({
    required int page,
    required int pageSize,
  }) async {
    try {
      emit(MessageLoading());

      final messages = await _messageService.getMessagesWithPagination(
        page: page,
        pageSize: pageSize,
      );

      final messagesWithStatus = messages
          .map((msg) => MessageWithStatus(
                message: msg,
                status: MessageStatus.sent,
                isDelivered: true,
                isRead: msg.isRead,
              ))
          .toList();

      if (messages.isEmpty) {
        emit(MessageError(message: 'No messages found for page $page'));
      } else {
        emit(PaginatedMessagesLoaded(
          messages: messagesWithStatus,
          page: page,
          pageSize: pageSize,
        ));
      }
    } catch (e) {
      log('Error loading paginated messages: $e');
      emit(MessageError(message: 'Failed to load paginated messages: $e'));
    }
  }

  Future<void> loadMessageThread(int messageId) async {
    try {
      emit(MessageLoading());

      final messages = await _messageService.getMessageThread(messageId);

      final messagesWithStatus = messages
          .map((msg) => MessageWithStatus(
                message: msg,
                status: MessageStatus.sent,
                isDelivered: true,
                isRead: msg.isRead,
              ))
          .toList();

      if (messages.isEmpty) {
        emit(MessageError(message: 'No thread found for message $messageId'));
      } else {
        emit(MessageThreadLoaded(
          messages: messagesWithStatus,
          rootMessageId: messageId,
        ));
      }
    } catch (e) {
      log('Error loading message thread: $e');
      emit(MessageError(message: 'Failed to load message thread: $e'));
    }
  }

  Future<void> loadChatHistory({
    required int withUserId,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      emit(MessageLoading());

      final messages = await _messageService.getChatHistory(
        withUserId: withUserId,
        page: page,
        pageSize: pageSize,
      );

      final messagesWithStatus = messages
          .map((msg) => MessageWithStatus(
                message: msg,
                status: MessageStatus.sent,
                isDelivered: true,
                isRead: false,
              ))
          .toList();

      messagesWithStatus
          .sort((a, b) => a.message.timestamp.compareTo(b.message.timestamp));

      _updateChatMessages(withUserId, messagesWithStatus);

      if (messages.isEmpty) {
        emit(ChatEmpty(
          otherUserId: withUserId,
          otherUserName: 'User $withUserId',
        ));
      } else {
        emit(ChatLoaded(
          messages: messagesWithStatus,
          otherUserId: withUserId,
          otherUserName: 'User $withUserId',
          isOtherUserOnline: true,
        ));
      }
    } catch (e) {
      log('Error loading chat history: $e');
      emit(MessageError(message: 'Failed to load chat history: $e'));
    }
  }

  Future<void> sendMessage({
    required int receiverId,
    required String content,
  }) async {
    try {
      await stopTyping(receiverId);
      final clientTempId = UniqueKey().toString();
      final tempId = DateTime.now().millisecondsSinceEpoch;
      final tempMessage = MessageWithStatus(
        message: Message(
          id: tempId,
          senderId: _signalRService.currentUserId ?? 0,
          receiverId: receiverId,
          content: content,
          timestamp: DateTime.now(),
          isRead: false,
        ),
        status: MessageStatus.sending,
        isDelivered: false,
        isRead: false,
        clientTempId: clientTempId,
      );
      final currentMessages = _chatMessages[receiverId] ?? [];
      final updatedMessages = List<MessageWithStatus>.from(currentMessages);
      updatedMessages.add(tempMessage);
      updatedMessages
          .sort((a, b) => a.message.timestamp.compareTo(b.message.timestamp));
      _updateChatMessages(receiverId, updatedMessages);
      final signalRSuccess = await _signalRService.sendMessage(
        receiverId: receiverId,
        content: content,
      );
      if (signalRSuccess) {
        final sentMessage = MessageWithStatus(
          message: tempMessage.message,
          status: MessageStatus.sent,
          isDelivered: true,
          isRead: false,
          clientTempId: clientTempId,
        );
        final messagesToUpdate = _chatMessages[receiverId] ?? [];
        final updatedMessagesList = messagesToUpdate.map((msg) {
          if (msg.clientTempId == clientTempId) {
            return sentMessage;
          }
          return msg;
        }).toList();
        _updateChatMessages(receiverId, updatedMessagesList);
        emit(MessageSent(message: tempMessage.message));
      } else {
        final failedMessage = MessageWithStatus(
          message: tempMessage.message,
          status: MessageStatus.failed,
          isDelivered: false,
          isRead: false,
          clientTempId: clientTempId,
        );
        final messagesToUpdate = _chatMessages[receiverId] ?? [];
        final updatedMessagesList = messagesToUpdate.map((msg) {
          if (msg.clientTempId == clientTempId) {
            return failedMessage;
          }
          return msg;
        }).toList();
        _updateChatMessages(receiverId, updatedMessagesList);
        emit(MessageSendFailed(
          content: content,
          errorMessage: 'Failed to send message via SignalR',
        ));
      }
    } catch (e) {
      log('Error sending message: $e');
      emit(MessageSendFailed(
        content: content,
        errorMessage: 'Error sending message: $e',
      ));
    }
  }

  Future<void> startTyping(int receiverId) async {
    try {
      _typingTimers[receiverId]?.cancel();

      final now = DateTime.now();
      final lastTypingTime = _lastTypingTime[receiverId];

      if (lastTypingTime == null ||
          now.difference(lastTypingTime) > _typingDebounce) {
        final success = await _signalRService.sendTypingIndicator(
          receiverId: receiverId,
          isTyping: true,
        );

        if (success) {
          _lastTypingTime[receiverId] = now;
          _isTypingMap[receiverId] = true;

          emit(UserTypingStatusChanged(
            userId: _signalRService.currentUserId ?? 0,
            isTyping: true,
            targetUserId: receiverId,
          ));
        }
      }

      _typingTimers[receiverId] = Timer(_typingTimeout, () {
        stopTyping(receiverId);
      });
    } catch (e) {
      log('Error starting typing indicator: $e');
    }
  }

  Future<void> stopTyping(int receiverId) async {
    try {
      _typingTimers[receiverId]?.cancel();
      _typingTimers.remove(receiverId);

      if (_isTypingMap[receiverId] == true) {
        final success = await _signalRService.sendTypingIndicator(
          receiverId: receiverId,
          isTyping: false,
        );

        if (success) {
          _isTypingMap[receiverId] = false;
          _lastTypingTime.remove(receiverId);

          emit(UserTypingStatusChanged(
            userId: _signalRService.currentUserId ?? 0,
            isTyping: false,
            targetUserId: receiverId,
          ));
        }
      }
    } catch (e) {
      log('Error stopping typing indicator: $e');
    }
  }

  void _handleNewMessage(Message message) {
    try {
      // Stop typing indicator from sender
      if (_isTypingMap[message.senderId] == true) {
        _isTypingMap[message.senderId] = false;
        emit(UserTypingStatusChanged(
          userId: message.senderId,
          isTyping: false,
          targetUserId: _signalRService.currentUserId ?? 0,
        ));
      }

      emit(NewMessageReceived(message: message));

      final currentUserId = _signalRService.currentUserId ?? 0;
      final chatUserId = message.senderId == currentUserId
          ? message.receiverId
          : message.senderId;

      final currentMessages = _chatMessages[chatUserId] ?? [];
      final newMessageWithStatus = MessageWithStatus(
        message: message,
        status: message.senderId == currentUserId
            ? MessageStatus.sent
            : MessageStatus.received,
        isDelivered: true,
        isRead: false,
      );

      final updatedMessages = List<MessageWithStatus>.from(currentMessages);
      final optimisticIndex = updatedMessages.indexWhere((msg) =>
          msg.clientTempId != null &&
          msg.message.content == message.content &&
          msg.message.senderId == message.senderId &&
          msg.message.timestamp.difference(message.timestamp).inSeconds.abs() <
              5);
      if (optimisticIndex != -1) {
        // Replace the optimistic message with the real one
        updatedMessages[optimisticIndex] = newMessageWithStatus;
      } else {
        // Check if message already exists (to avoid duplicates)
        final existingIndex =
            updatedMessages.indexWhere((msg) => msg.message.id == message.id);
        if (existingIndex == -1) {
          updatedMessages.add(newMessageWithStatus);
        } else {
          updatedMessages[existingIndex] = newMessageWithStatus;
        }
      }
      updatedMessages
          .sort((a, b) => a.message.timestamp.compareTo(b.message.timestamp));
      _updateChatMessages(chatUserId, updatedMessages);

      if (state is ChatLoaded) {
        final chatState = state as ChatLoaded;
        if (chatState.otherUserId == chatUserId) {
          emit(ChatLoaded(
            messages: updatedMessages,
            otherUserId: chatState.otherUserId,
            otherUserName: chatState.otherUserName,
            isOtherUserOnline: chatState.isOtherUserOnline,
          ));
        }
      }
    } catch (e) {
      log('Error handling new message: $e');
    }
  }

  void _handleTypingIndicator(Map<String, dynamic> typingData) {
    try {
      final userId = typingData['userId'] as int?;
      final isTyping = typingData['isTyping'] as bool? ?? false;

      if (userId != null) {
        _isTypingMap[userId] = isTyping;

        emit(UserTypingStatusChanged(
          userId: userId,
          isTyping: isTyping,
          targetUserId: _signalRService.currentUserId ?? 0,
        ));

        if (isTyping) {
          _typingTimers[userId]?.cancel();
          _typingTimers[userId] = Timer(_typingTimeout, () {
            if (_isTypingMap[userId] == true) {
              _isTypingMap[userId] = false;
              emit(UserTypingStatusChanged(
                userId: userId,
                isTyping: false,
                targetUserId: _signalRService.currentUserId ?? 0,
              ));
            }
          });
        } else {
          _typingTimers[userId]?.cancel();
          _typingTimers.remove(userId);
        }
      }
    } catch (e) {
      log('Error handling typing indicator: $e');
    }
  }

  bool isUserTyping(int userId) {
    return _isTypingMap[userId] == true;
  }

  // Get list of users currently typing
  List<int> getTypingUsers() {
    return _isTypingMap.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  Future<void> markMessageAsRead(int messageId) async {
    try {
      final success = await _messageService.markMessageAsRead(messageId);
      if (success) {
        _updateMessageReadStatus(messageId, true);
        emit(MessageMarkedAsRead(messageId: messageId));
        await loadUnreadCount();
      }
    } catch (e) {
      log('Error marking message as read: $e');
    }
  }

  void _updateMessageReadStatus(int messageId, bool isRead) {
    for (final entry in _chatMessages.entries) {
      final messages = entry.value;
      final messageIndex =
          messages.indexWhere((msg) => msg.message.id == messageId);
      if (messageIndex != -1) {
        final updatedMessages = List<MessageWithStatus>.from(messages);
        final originalMessage = updatedMessages[messageIndex];

        final updatedMessage = Message(
          id: originalMessage.message.id,
          senderId: originalMessage.message.senderId,
          receiverId: originalMessage.message.receiverId,
          content: originalMessage.message.content,
          timestamp: originalMessage.message.timestamp,
          isRead: isRead,
          messageType: originalMessage.message.messageType,
        );

        updatedMessages[messageIndex] = MessageWithStatus(
          message: updatedMessage,
          status: originalMessage.status,
          isDelivered: originalMessage.isDelivered,
          isRead: isRead,
          clientTempId: originalMessage.clientTempId,
        );

        _updateChatMessages(entry.key, updatedMessages);
      }
    }
  }

  Future<void> markAllMessagesAsRead(int userId) async {
    try {
      final success = await _messageService.markAllMessagesAsRead(userId);
      if (success) {
        _updateAllMessagesReadStatus(userId, true);
        emit(MessageOperationSuccess(
          message: 'All messages marked as read',
          actionType: 'mark_all_read',
        ));
        await loadUnreadCount();
      } else {
        log('Failed to mark messages as read for user $userId');
      }
    } catch (e) {
      log('Error marking messages as read: $e');
    }
  }

  void _updateAllMessagesReadStatus(int userId, bool isRead) {
    for (final entry in _chatMessages.entries) {
      if (entry.key == userId) {
        final messages = entry.value;
        final updatedMessages = messages.map((msg) {
          if (msg.message.senderId != (_signalRService.currentUserId ?? 0)) {
            final updatedMessage = Message(
              id: msg.message.id,
              senderId: msg.message.senderId,
              receiverId: msg.message.receiverId,
              content: msg.message.content,
              timestamp: msg.message.timestamp,
              isRead: isRead,
              messageType: msg.message.messageType,
            );

            return MessageWithStatus(
              message: updatedMessage,
              status: msg.status,
              isDelivered: msg.isDelivered,
              isRead: isRead,
              clientTempId: msg.clientTempId,
            );
          }
          return msg;
        }).toList();

        _updateChatMessages(userId, updatedMessages);
      }
    }
  }

  // Delete message
  Future<void> deleteMessage(int messageId) async {
    try {
      final success = await _messageService.deleteMessage(messageId);
      if (success) {
        emit(MessageDeleted(messageId: messageId));
      }
    } catch (e) {
      log('Error deleting message: $e');
    }
  }

  // Search messages
  Future<void> searchMessages(String query) async {
    try {
      emit(MessageLoading());
      final messages = await _messageService.searchMessages(query);

      final messagesWithStatus = messages
          .map((msg) => MessageWithStatus(
                message: msg,
                status: MessageStatus.sent,
                isDelivered: true,
                isRead: true,
              ))
          .toList();

      emit(MessageSearchResults(
        query: query,
        results: messagesWithStatus,
      ));
    } catch (e) {
      log('Error searching messages: $e');
      emit(MessageError(message: 'Failed to search messages: $e'));
    }
  }

  void cleanupTypingIndicators(int userId) {
    _typingTimers[userId]?.cancel();
    _typingTimers.remove(userId);
    _isTypingMap.remove(userId);
    _lastTypingTime.remove(userId);
  }

  // Clean up all typing indicators
  void cleanupAllTypingIndicators() {
    for (final timer in _typingTimers.values) {
      timer?.cancel();
    }
    _typingTimers.clear();
    _isTypingMap.clear();
    _lastTypingTime.clear();
  }

  void cleanupChatStream(int withUserId) {
    _chatStreams[withUserId]?.close();
    _chatStreams.remove(withUserId);
    _chatMessages.remove(withUserId);
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    cleanupAllTypingIndicators();

    for (final stream in _chatStreams.values) {
      stream.close();
    }
    _chatStreams.clear();
    _chatMessages.clear();

    return super.close();
  }
}
