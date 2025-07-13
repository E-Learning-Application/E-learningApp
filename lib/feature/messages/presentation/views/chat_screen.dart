import 'package:e_learning_app/feature/messages/data/message_cubit.dart';
import 'package:e_learning_app/feature/messages/presentation/views/time_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../../core/model/match_response.dart';
import '../../../../core/service/matching_service.dart';
import '../../../../core/service/signalr_service.dart' as signalr;
import '../../../../core/model/message_model.dart' hide MessageStatus;
import '../../../../feature/messages/data/message_state.dart' as msg_state;
import 'package:e_learning_app/feature/Auth/data/auth_cubit.dart';

class ChatMessage {
  final String id;
  final String content;
  final bool isCurrentUser;
  final DateTime timestamp;
  final MessageType type;
  final msg_state.MessageStatus status;
  final bool isRead; // Added for marking messages as read

  ChatMessage({
    required this.id,
    required this.content,
    required this.isCurrentUser,
    required this.timestamp,
    this.type = MessageType.text,
    this.status = msg_state.MessageStatus.sent,
    this.isRead = false, // Default to false
  });

  factory ChatMessage.fromMessageWithStatus(
      msg_state.MessageWithStatus messageWithStatus, int currentUserId) {
    return ChatMessage(
      id: messageWithStatus.message.id.toString(),
      content: messageWithStatus.message.content,
      isCurrentUser: messageWithStatus.message.senderId == currentUserId,
      timestamp: messageWithStatus.message.timestamp,
      status: messageWithStatus.status,
      type: MessageType.text,
      isRead: messageWithStatus.message.isRead, // Use the actual isRead status
    );
  }

  factory ChatMessage.fromMessage(Message message, int currentUserId) {
    return ChatMessage(
      id: message.id.toString(),
      content: message.content,
      isCurrentUser: message.senderId == currentUserId,
      timestamp: message.timestamp,
      type: MessageType.text,
      isRead: message.isRead, // Use the actual isRead status
    );
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isCurrentUser,
    DateTime? timestamp,
    MessageType? type,
    msg_state.MessageStatus? status,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
    );
  }
}

enum MessageType { text, image, audio, video }

class ChatScreen extends StatefulWidget {
  final MatchResponse match;
  final MatchingService matchingService;
  final signalr.SignalRService signalRService;

  const ChatScreen({
    Key? key,
    required this.match,
    required this.matchingService,
    required this.signalRService,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSendingMessage = false;
  List<ChatMessage> _messages = [];
  Timer? _typingTimer;
  bool _isTyping = false;
  StreamSubscription<List<msg_state.MessageWithStatus>>?
      _messageStreamSubscription;
  bool _isLoading = true;
  int? _currentUserId;
  Set<int> _readMessageIds =
      {}; // Track which messages have been marked as read

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadChatHistory();
    _setupTypingListener();
    _markMessagesAsRead();
    _setupMessageStream();
  }

  void _loadCurrentUserId() {
    final authCubit = context.read<AuthCubit>();
    setState(() {
      _currentUserId = authCubit.currentUser?.userId;
    });
  }

  void _setupMessageStream() {
    final messageCubit = context.read<MessageCubit>();
    _messageStreamSubscription = messageCubit
        .getChatStream(widget.match.matchedUser.id)
        .listen((messagesWithStatus) {
      setState(() {
        _messages = messagesWithStatus
            .map((msg) =>
                ChatMessage.fromMessageWithStatus(msg, _currentUserId ?? 0))
            .toList();
        _isLoading = false;
      });

      // Mark unread messages as read when they are displayed
      _markUnreadMessagesAsRead(messagesWithStatus);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollToBottom();
        }
      });
    });
  }

  void _markUnreadMessagesAsRead(List<msg_state.MessageWithStatus> messages) {
    final messageCubit = context.read<MessageCubit>();
    final currentUserId = _currentUserId ?? 0;

    for (final messageWithStatus in messages) {
      final message = messageWithStatus.message;

      // Only mark messages as read if:
      // 1. The message is not from the current user
      // 2. The message is not already read
      // 3. The message hasn't been marked as read in this session
      if (message.senderId != currentUserId &&
          !message.isRead &&
          !_readMessageIds.contains(message.id)) {
        messageCubit.markMessageAsRead(message.id);
        _readMessageIds.add(message.id);
      }
    }
  }

  void _setupTypingListener() {
    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        _startTyping();
      } else if (_messageController.text.isEmpty && _isTyping) {
        _stopTyping();
      }
    });
  }

  void _startTyping() {
    if (!_isTyping) {
      setState(() {
        _isTyping = true;
      });
      final messageCubit = context.read<MessageCubit>();
      messageCubit.startTyping(widget.match.matchedUser.id);
    }
  }

  void _stopTyping() {
    if (_isTyping) {
      setState(() {
        _isTyping = false;
      });
      final messageCubit = context.read<MessageCubit>();
      messageCubit.stopTyping(widget.match.matchedUser.id);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _messageStreamSubscription?.cancel();
    _stopTyping();

    // Clean up the chat stream
    final messageCubit = context.read<MessageCubit>();
    messageCubit.cleanupChatStream(widget.match.matchedUser.id);

    super.dispose();
  }

  void _loadChatHistory() {
    final messageCubit = context.read<MessageCubit>();
    messageCubit.loadChatHistory(withUserId: widget.match.matchedUser.id);
  }

  void _markMessagesAsRead() {
    final messageCubit = context.read<MessageCubit>();
    messageCubit.markAllMessagesAsRead(widget.match.matchedUser.id);
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSendingMessage) return;

    print(
        'ChatScreen: Sending message: "$messageText" to user ${widget.match.matchedUser.id}');

    setState(() {
      _isSendingMessage = true;
    });

    final messageCubit = context.read<MessageCubit>();
    await messageCubit.sendMessage(
      receiverId: widget.match.matchedUser.id,
      content: messageText,
    );

    _messageController.clear();
    _stopTyping();

    setState(() {
      _isSendingMessage = false;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    const baseUrl = 'https://elearningproject.runasp.net';
    return '$baseUrl$path';
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isCurrentUser = message.isCurrentUser;
    final bubbleColor = isCurrentUser ? Colors.blueAccent : Colors.grey[200];
    final textColor = isCurrentUser ? Colors.white : Colors.black87;
    final align =
        isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = isCurrentUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          );

    return GestureDetector(
      onTap: () {
        // Mark message as read when tapped (for received messages)
        if (!message.isCurrentUser && !message.isRead) {
          _markMessageAsRead(message.id);
        }
      },
      onLongPress: () {
        _showMessageOptions(message);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          // Add subtle border for unread messages
          border: (!message.isCurrentUser && !message.isRead)
              ? Border.all(color: Colors.blue.withOpacity(0.3), width: 1)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment:
              isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isCurrentUser) ...[
              CircleAvatar(
                radius: 18,
                backgroundImage: message.isCurrentUser
                    ? null
                    : (widget.match.matchedUser.profilePicture != null &&
                            widget.match.matchedUser.profilePicture!.isNotEmpty
                        ? NetworkImage(getFullImageUrl(
                            widget.match.matchedUser.profilePicture))
                        : null),
                child: widget.match.matchedUser.profilePicture == null ||
                        widget.match.matchedUser.profilePicture!.isEmpty
                    ? Text(
                        widget.match.matchedUser.username[0].toUpperCase(),
                        style: const TextStyle(fontSize: 14),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: align,
                children: [
                  Container(
                    padding: message.type == MessageType.image
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: message.type == MessageType.image
                          ? Colors.transparent
                          : bubbleColor,
                      borderRadius: radius,
                      boxShadow: message.type == MessageType.image
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.content,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(message.timestamp),
                                style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildMessageStatusIcon(message.status),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isCurrentUser) ...[
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildReadIndicator(message),
                    ),
                  ],
                ],
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageStatusIcon(msg_state.MessageStatus status) {
    switch (status) {
      case msg_state.MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        );
      case msg_state.MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.white70);
      case msg_state.MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Colors.white70);
      case msg_state.MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: Colors.blue);
      case msg_state.MessageStatus.failed:
        return const Icon(Icons.error, size: 12, color: Colors.red);
      default:
        return const SizedBox();
    }
  }

  Widget _buildReadIndicator(ChatMessage message) {
    if (message.isCurrentUser) {
      // For sent messages, show read status
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          _buildMessageStatusIcon(message.status),
        ],
      );
    } else {
      // For received messages, show read indicator if message is read
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
          if (message.isRead) ...[
            const SizedBox(width: 4),
            const Icon(Icons.done_all, size: 12, color: Colors.blue),
          ],
        ],
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    return TimeFormatter.formatChatTime(dateTime);
  }

  void _endMatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Match'),
        content: Text(
          'Are you sure you want to end the match with ${widget.match.matchedUser.username}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'End Match',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success = await widget.matchingService.endMatch(widget.match.id);
        if (success) {
          if (mounted) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Match ended successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to end match'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error ending match: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildTypingIndicator() {
    return BlocBuilder<MessageCubit, msg_state.MessageState>(
      buildWhen: (previous, current) =>
          current is msg_state.UserTypingStatusChanged &&
          current.userId == widget.match.matchedUser.id,
      builder: (context, state) {
        bool isOtherUserTyping = false;
        if (state is msg_state.UserTypingStatusChanged) {
          final messageCubit = context.read<MessageCubit>();
          isOtherUserTyping =
              messageCubit.isUserTyping(widget.match.matchedUser.id);
        }

        if (isOtherUserTyping) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: widget.match.matchedUser.profilePicture !=
                              null &&
                          widget.match.matchedUser.profilePicture!.isNotEmpty
                      ? NetworkImage(getFullImageUrl(
                          widget.match.matchedUser.profilePicture))
                      : null,
                  child: widget.match.matchedUser.profilePicture == null ||
                          widget.match.matchedUser.profilePicture!.isEmpty
                      ? Text(
                          widget.match.matchedUser.username[0].toUpperCase(),
                          style: const TextStyle(fontSize: 14),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'typing',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Message'),
                onTap: () {
                  Navigator.pop(context);
                  _copyMessage(message.content);
                },
              ),
              if (message.isCurrentUser)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Message',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyMessage(String content) {
    // TODO: Implement clipboard functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteMessage(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final messageCubit = context.read<MessageCubit>();
        await messageCubit.deleteMessage(int.parse(message.id));

        setState(() {
          _messages.removeWhere((msg) => msg.id == message.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _markMessageAsRead(String messageId) {
    try {
      final messageCubit = context.read<MessageCubit>();
      final id = int.tryParse(messageId);
      if (id != null) {
        messageCubit.markMessageAsRead(id);
      }
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.match.matchedUser.username),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile view coming soon!'),
                    ),
                  );
                  break;
                case 'report':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report feature coming soon!'),
                    ),
                  );
                  break;
                case 'end':
                  _endMatch();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('View Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report),
                    SizedBox(width: 8),
                    Text('Report User'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'end',
                child: Row(
                  children: [
                    Icon(Icons.close),
                    SizedBox(width: 8),
                    Text('End Match'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocListener<MessageCubit, msg_state.MessageState>(
        listener: (context, state) {
          if (state is msg_state.MessageError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is msg_state.MessageSendFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send: ${state.errorMessage}'),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is msg_state.MessageMarkedAsRead) {
            // Update the message status in the UI when marked as read
            setState(() {
              for (int i = 0; i < _messages.length; i++) {
                if (_messages[i].id == state.messageId.toString()) {
                  _messages[i] = _messages[i].copyWith(isRead: true);
                  break;
                }
              }
            });
          } else if (state is msg_state.MessageOperationSuccess) {
            if (state.actionType == 'mark_all_read') {
              // Update all messages to show as read
              setState(() {
                for (int i = 0; i < _messages.length; i++) {
                  _messages[i] = _messages[i].copyWith(isRead: true);
                }
              });
            }
          }
        },
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages yet. Start the conversation!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _messages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return _buildTypingIndicator();
                            }
                            final message = _messages[index];
                            return _buildMessageBubble(message);
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSendingMessage ? null : _sendMessage,
                    icon: _isSendingMessage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
