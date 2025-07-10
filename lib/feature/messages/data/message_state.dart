import 'package:e_learning_app/core/model/message_model.dart';
import 'package:equatable/equatable.dart';

abstract class MessageState extends Equatable {
  const MessageState();

  @override
  List<Object?> get props => [];
}

class MessageInitial extends MessageState {}

class MessageLoading extends MessageState {}

class MessageError extends MessageState {
  final String message;
  final String? errorCode;

  const MessageError({
    required this.message,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, errorCode];
}

// Chat List States
class ChatListLoaded extends MessageState {
  final List<ChatSummary> chats;
  final int totalUnreadCount;

  const ChatListLoaded({
    required this.chats,
    required this.totalUnreadCount,
  });

  @override
  List<Object?> get props => [chats, totalUnreadCount];
}

class ChatListEmpty extends MessageState {}

// Individual Chat States
class ChatLoaded extends MessageState {
  final List<MessageWithStatus> messages;
  final int otherUserId;
  final String otherUserName;
  final bool isOtherUserOnline;

  const ChatLoaded({
    required this.messages,
    required this.otherUserId,
    required this.otherUserName,
    required this.isOtherUserOnline,
  });

  @override
  List<Object?> get props =>
      [messages, otherUserId, otherUserName, isOtherUserOnline];
}

class ChatEmpty extends MessageState {
  final int otherUserId;
  final String otherUserName;

  const ChatEmpty({
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  List<Object?> get props => [otherUserId, otherUserName];
}

// Message Sending States
class MessageSending extends MessageState {
  final MessageWithStatus message;

  const MessageSending({required this.message});

  @override
  List<Object?> get props => [message];
}

class MessageSent extends MessageState {
  final Message message;

  const MessageSent({required this.message});

  @override
  List<Object?> get props => [message];
}

class MessageSendFailed extends MessageState {
  final String content;
  final String errorMessage;

  const MessageSendFailed({
    required this.content,
    required this.errorMessage,
  });

  @override
  List<Object?> get props => [content, errorMessage];
}

// Real-time Message States
class NewMessageReceived extends MessageState {
  final Message message;

  const NewMessageReceived({required this.message});

  @override
  List<Object?> get props => [message];
}

class MessageStatusUpdated extends MessageState {
  final int messageId;
  final MessageStatus status;

  const MessageStatusUpdated({
    required this.messageId,
    required this.status,
  });

  @override
  List<Object?> get props => [messageId, status];
}

class UserOnlineStatusChanged extends MessageState {
  final int userId;
  final bool isOnline;

  const UserOnlineStatusChanged({
    required this.userId,
    required this.isOnline,
  });

  @override
  List<Object?> get props => [userId, isOnline];
}

class UserTypingStatusChanged extends MessageState {
  final int userId;
  final bool isTyping;
  final int targetUserId;

  const UserTypingStatusChanged({
    required this.userId,
    required this.isTyping,
    required this.targetUserId,
  });

  @override
  List<Object?> get props => [userId, isTyping, targetUserId];
}

class TypingIndicatorTimeout extends MessageState {
  final int userId;

  const TypingIndicatorTimeout({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class MessageSearchResults extends MessageState {
  final String query;
  final List<MessageWithStatus> results;

  const MessageSearchResults({
    required this.query,
    required this.results,
  });

  @override
  List<Object?> get props => [query, results];
}

class MessageOperationSuccess extends MessageState {
  final String message;
  final String? actionType;

  const MessageOperationSuccess({
    required this.message,
    this.actionType,
  });

  @override
  List<Object?> get props => [message, actionType];
}

class MessageDeleted extends MessageState {
  final int messageId;

  const MessageDeleted({required this.messageId});

  @override
  List<Object?> get props => [messageId];
}

class MessageMarkedAsRead extends MessageState {
  final int messageId;

  const MessageMarkedAsRead({required this.messageId});

  @override
  List<Object?> get props => [messageId];
}

class UnreadCountUpdated extends MessageState {
  final int count;

  const UnreadCountUpdated({required this.count});

  @override
  List<Object?> get props => [count];
}

class MessageWithStatus {
  final Message message;
  final MessageStatus status;
  final bool isDelivered;
  final bool isRead;

  const MessageWithStatus({
    required this.message,
    required this.status,
    required this.isDelivered,
    required this.isRead,
  });
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
  received,
}
