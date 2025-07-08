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
      userName: json['userName'] ?? '',
      profileImage: json['profileImage'],
      lastMessage: json['lastMessage'] ?? '',
      lastMessageTime: DateTime.parse(
          json['lastMessageTime'] ?? DateTime.now().toIso8601String()),
      unreadCount: json['unreadCount'] ?? 0,
      isOnline: json['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'profileImage': profileImage,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'isOnline': isOnline,
    };
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

class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String messageType;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    required this.isRead,
    this.messageType = 'text',
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
    };
  }
}
