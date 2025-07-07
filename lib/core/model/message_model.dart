// lib/core/models/message_models.dart

class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String messageType; // text, image, file, etc.
  final String? senderName;
  final String? senderProfileImage;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    required this.isRead,
    required this.messageType,
    this.senderName,
    this.senderProfileImage,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? 0,
      senderId: json['senderId'] ?? 0,
      receiverId: json['receiverId'] ?? 0,
      content: json['content'] ?? '',
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isRead: json['isRead'] ?? false,
      messageType: json['messageType'] ?? 'text',
      senderName: json['senderName'],
      senderProfileImage: json['senderProfileImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'messageType': messageType,
      'senderName': senderName,
      'senderProfileImage': senderProfileImage,
    };
  }

  Message copyWith({
    int? id,
    int? senderId,
    int? receiverId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    String? messageType,
    String? senderName,
    String? senderProfileImage,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      messageType: messageType ?? this.messageType,
      senderName: senderName ?? this.senderName,
      senderProfileImage: senderProfileImage ?? this.senderProfileImage,
    );
  }
}

class ChatSummary {
  final int userId;
  final String userName;
  final String? profileImage;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  ChatSummary({
    required this.userId,
    required this.userName,
    this.profileImage,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isOnline,
  });

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    return ChatSummary(
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? 'Unknown',
      profileImage: json['profileImage'],
      lastMessage: json['lastMessage'] ?? '',
      lastMessageTime: DateTime.parse(
          json['lastMessageTime'] ?? DateTime.now().toIso8601String()),
      unreadCount: json['unreadCount'] ?? 0,
      isOnline: json['isOnline'] ?? false,
    );
  }
}

class SendMessageRequest {
  final int receiverId;
  final String content;
  final String messageType;

  SendMessageRequest({
    required this.receiverId,
    required this.content,
    this.messageType = 'text',
  });

  Map<String, dynamic> toJson() {
    return {
      'receiverId': receiverId,
      'content': content,
      'messageType': messageType,
    };
  }
}

class UserMatch {
  final int id;
  final int userId1;
  final int userId2;
  final String matchType;
  final DateTime createdAt;
  final bool isActive;
  final String? matchedUserName;
  final String? matchedUserProfileImage;
  final bool? matchedUserIsOnline;

  UserMatch({
    required this.id,
    required this.userId1,
    required this.userId2,
    required this.matchType,
    required this.createdAt,
    required this.isActive,
    this.matchedUserName,
    this.matchedUserProfileImage,
    this.matchedUserIsOnline,
  });

  factory UserMatch.fromJson(Map<String, dynamic> json) {
    return UserMatch(
      id: json['id'] ?? 0,
      userId1: json['userId1'] ?? 0,
      userId2: json['userId2'] ?? 0,
      matchType: json['matchType'] ?? 'text',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isActive: json['isActive'] ?? false,
      matchedUserName: json['matchedUserName'],
      matchedUserProfileImage: json['matchedUserProfileImage'],
      matchedUserIsOnline: json['matchedUserIsOnline'],
    );
  }
}

class UserMatchRequest {
  final int userId;
  final String matchType;

  UserMatchRequest({
    required this.userId,
    required this.matchType,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'matchType': matchType,
    };
  }
}

enum MatchType {
  text('text'),
  voice('voice'),
  video('video');

  const MatchType(this.value);
  final String value;
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class MessageWithStatus {
  final Message message;
  final MessageStatus status;

  MessageWithStatus({
    required this.message,
    required this.status,
  });

  MessageWithStatus copyWith({
    Message? message,
    MessageStatus? status,
  }) {
    return MessageWithStatus(
      message: message ?? this.message,
      status: status ?? this.status,
    );
  }
}
