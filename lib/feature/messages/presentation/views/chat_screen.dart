import 'package:e_learning_app/feature/messages/data/message_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../../core/model/match_response.dart';
import '../../../../core/service/matching_service.dart';
import '../../../../core/service/signalr_service.dart' as signalr;
import '../../../../core/model/message_model.dart';
import '../../../../feature/messages/data/message_state.dart'
    hide MessageStatus, MessageWithStatus;

class ChatMessage {
  final String id;
  final String content;
  final bool isCurrentUser;
  final DateTime timestamp;
  final MessageType type;
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isCurrentUser,
    required this.timestamp,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
  });

  factory ChatMessage.fromMessageWithStatus(
      MessageWithStatus messageWithStatus, int currentUserId) {
    return ChatMessage(
      id: messageWithStatus.message.id.toString(),
      content: messageWithStatus.message.content,
      isCurrentUser: messageWithStatus.message.senderId == currentUserId,
      timestamp: messageWithStatus.message.timestamp,
      status: messageWithStatus.status,
    );
  }

  factory ChatMessage.fromMessage(Message message, int currentUserId) {
    return ChatMessage(
      id: message.id.toString(),
      content: message.content,
      isCurrentUser: message.senderId == currentUserId,
      timestamp: message.timestamp,
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
  final List<ChatMessage> _messages = [];
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _setupMessageListener();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _setupMessageListener() {
    _messageController.addListener(() {
      _handleTyping();
    });
  }

  void _handleTyping() {
    final messageCubit = context.read<MessageCubit>();

    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      messageCubit.startTyping(widget.match.matchedUser.id);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 1), () {
      if (_isTyping) {
        _isTyping = false;
        messageCubit.stopTyping(widget.match.matchedUser.id);
      }
    });
  }

  void _loadChatHistory() {
    final messageCubit = context.read<MessageCubit>();
    messageCubit.loadChatHistory(withUserId: widget.match.matchedUser.id);
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSendingMessage) return;

    setState(() {
      _isSendingMessage = true;
    });

    final messageCubit = context.read<MessageCubit>();
    await messageCubit.sendMessage(
      receiverId: widget.match.matchedUser.id,
      content: messageText,
    );

    _messageController.clear();

    setState(() {
      _isSendingMessage = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.match.matchedUser.profilePicture != null
                  ? NetworkImage(widget.match.matchedUser.profilePicture!)
                  : null,
              child: widget.match.matchedUser.profilePicture == null
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: radius,
                    boxShadow: [
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
                              _formatMessageTime(message.timestamp),
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
                    child: Text(
                      _formatMessageTime(message.timestamp),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
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
    );
  }

  Widget _buildMessageStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        );
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: Colors.blue);
      case MessageStatus.failed:
        return const Icon(Icons.error, size: 12, color: Colors.red);
      default:
        return const SizedBox();
    }
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: widget.match.matchedUser.profilePicture != null
                ? NetworkImage(widget.match.matchedUser.profilePicture!)
                : null,
            child: widget.match.matchedUser.profilePicture == null
                ? Text(
                    widget.match.matchedUser.username[0].toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.5 + (value * 0.5),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[600]?.withOpacity(0.3 + (value * 0.7)),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
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

  void _updateMessagesFromState(MessageState state) {
    final currentUserId = widget.signalRService.currentUserId ?? 0;

    if (state is ChatLoaded &&
        state.otherUserId == widget.match.matchedUser.id) {
      setState(() {
        _messages.clear();
        _messages.addAll(
          state.messages.map((msg) => ChatMessage.fromMessageWithStatus(
                msg as dynamic, // Cast to dynamic to bypass type mismatch
                currentUserId,
              )),
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else if (state is NewMessageReceived) {
      final message = state.message;
      if (message.senderId == widget.match.matchedUser.id ||
          message.receiverId == widget.match.matchedUser.id) {
        setState(() {
          _messages.add(ChatMessage.fromMessage(message, currentUserId));
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
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
            Text(
              widget.match.matchType.toUpperCase(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (widget.match.matchType == 'video')
            IconButton(
              icon: const Icon(Icons.videocam),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Video call feature coming soon!'),
                  ),
                );
              },
            ),
          if (widget.match.matchType == 'voice')
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voice call feature coming soon!'),
                  ),
                );
              },
            ),
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
                case 'block':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Block feature coming soon!'),
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
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block),
                    SizedBox(width: 8),
                    Text('Block User'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'end',
                child: Row(
                  children: [
                    Icon(Icons.call_end, color: Colors.red),
                    SizedBox(width: 8),
                    Text('End Match', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocListener<MessageCubit, MessageState>(
        listener: (context, state) {
          _updateMessagesFromState(state);

          if (state is MessageError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is MessageSendFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send: ${state.errorMessage}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<MessageCubit, MessageState>(
                builder: (context, state) {
                  if (state is MessageLoading) {
                    return _buildLoadingIndicator();
                  }

                  if (_messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'No messages yet. Start the conversation!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  final messageCubit = context.read<MessageCubit>();
                  final isOtherUserTyping =
                      messageCubit.isUserTyping(widget.match.matchedUser.id);

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length + (isOtherUserTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && isOtherUserTyping) {
                        return _buildTypingIndicator();
                      }

                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  );
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
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      minLines: 1,
                      maxLines: 5,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: _isSendingMessage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: _isSendingMessage ? null : _sendMessage,
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
