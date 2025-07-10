import 'package:e_learning_app/feature/messages/data/message_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import '../../../../core/model/match_response.dart';
import '../../../../core/service/matching_service.dart';
import '../../../../core/service/signalr_service.dart' as signalr;
import '../../../../core/model/message_model.dart' hide MessageStatus;
import '../../../../feature/messages/data/message_state.dart' as msg_state;
import '../../../../core/service/auth_service.dart';

class ChatMessage {
  final String id;
  final String content;
  final bool isCurrentUser;
  final DateTime timestamp;
  final MessageType type;
  final msg_state.MessageStatus status;
  final String? imageUrl;
  final File? localImageFile;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isCurrentUser,
    required this.timestamp,
    this.type = MessageType.text,
    this.status = msg_state.MessageStatus.sent,
    this.imageUrl,
    this.localImageFile,
  });

  factory ChatMessage.fromMessageWithStatus(
      msg_state.MessageWithStatus messageWithStatus, int currentUserId) {
    return ChatMessage(
      id: messageWithStatus.message.id.toString(),
      content: messageWithStatus.message.content,
      isCurrentUser: messageWithStatus.message.senderId == currentUserId,
      timestamp: messageWithStatus.message.timestamp,
      status: messageWithStatus.status,
      type: messageWithStatus.message.content.startsWith('http') &&
              (messageWithStatus.message.content.contains('.jpg') ||
                  messageWithStatus.message.content.contains('.jpeg') ||
                  messageWithStatus.message.content.contains('.png') ||
                  messageWithStatus.message.content.contains('.gif'))
          ? MessageType.image
          : MessageType.text,
      imageUrl: messageWithStatus.message.content.startsWith('http')
          ? messageWithStatus.message.content
          : null,
    );
  }

  factory ChatMessage.fromMessage(Message message, int currentUserId) {
    return ChatMessage(
      id: message.id.toString(),
      content: message.content,
      isCurrentUser: message.senderId == currentUserId,
      timestamp: message.timestamp,
      type: message.content.startsWith('http') &&
              (message.content.contains('.jpg') ||
                  message.content.contains('.jpeg') ||
                  message.content.contains('.png') ||
                  message.content.contains('.gif'))
          ? MessageType.image
          : MessageType.text,
      imageUrl: message.content.startsWith('http') ? message.content : null,
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
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSendingMessage = false;
  bool _isUploadingImage = false;
  final List<ChatMessage> _messages = [];
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _setupTypingListener();
    _markMessagesAsRead();
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
    _stopTyping();
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

    _scrollToBottom();
  }

  void _sendImage(File imageFile) async {
    if (_isUploadingImage) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Create temporary message for UI
      final tempMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Uploading image...',
        isCurrentUser: true,
        timestamp: DateTime.now(),
        type: MessageType.image,
        status: msg_state.MessageStatus.sending,
        localImageFile: imageFile,
      );

      setState(() {
        _messages.add(tempMessage);
      });
      _scrollToBottom();

      // TODO: Upload image to your server and get URL
      // For now, we'll simulate this process
      await Future.delayed(const Duration(seconds: 2));

      // Simulate getting image URL from server
      final imageUrl =
          'https://example.com/uploaded_image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Send the image URL as message content
      final messageCubit = context.read<MessageCubit>();
      await messageCubit.sendMessage(
        receiverId: widget.match.matchedUser.id,
        content: imageUrl,
      );

      // Remove temp message and let the real message come through the cubit
      setState(() {
        _messages.removeWhere((msg) => msg.id == tempMessage.id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  void _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        _sendImage(imageFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _takePicture() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        _sendImage(imageFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take picture: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _takePicture();
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

  String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    const baseUrl = 'https://elearningproject.runasp.net';
    return '$baseUrl$path';
  }

  void _showFullScreenImage(String imageUrl, {File? localFile}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: imageUrl,
          localFile: localFile,
        ),
      ),
    );
  }

  Widget _buildImageMessage(ChatMessage message) {
    final isCurrentUser = message.isCurrentUser;
    final imageWidget = message.localImageFile != null
        ? Image.file(
            message.localImageFile!,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
          )
        : message.imageUrl != null
            ? Image.network(
                message.imageUrl!,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 50),
                    ),
                  );
                },
              )
            : Container(
                width: 200,
                height: 200,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image, size: 50),
                ),
              );

    return GestureDetector(
      onTap: () {
        if (message.localImageFile != null) {
          _showFullScreenImage('', localFile: message.localImageFile!);
        } else if (message.imageUrl != null) {
          _showFullScreenImage(message.imageUrl!);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageWidget,
        ),
      ),
    );
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
      onLongPress: () {
        _showMessageOptions(message);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                        if (message.type == MessageType.image)
                          _buildImageMessage(message)
                        else
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
                                  color: message.type == MessageType.image
                                      ? Colors.grey[600]
                                      : textColor.withOpacity(0.7),
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

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ),
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

  void _updateMessagesFromState(msg_state.MessageState state) {
    final authService = AuthService(dioConsumer: context.read());
    authService.getCurrentUser().then((currentUser) {
      final currentUserId =
          currentUser?.userId ?? widget.signalRService.currentUserId ?? 0;

      print('ChatScreen: Current user ID: $currentUserId');
      print('ChatScreen: Matched user ID: ${widget.match.matchedUser.id}');

      if (state is msg_state.ChatLoaded &&
          state.otherUserId == widget.match.matchedUser.id) {
        print('ChatScreen: Updating messages from ChatLoaded state');
        print('ChatScreen: Number of messages: ${state.messages.length}');

        setState(() {
          _messages.clear();
          _messages.addAll(
            state.messages.map((msg) {
              final chatMessage = ChatMessage.fromMessageWithStatus(
                msg,
                currentUserId,
              );
              print(
                  'ChatScreen: Message ${chatMessage.id} - isCurrentUser: ${chatMessage.isCurrentUser}, content: "${chatMessage.content}"');
              return chatMessage;
            }),
          );
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else if (state is msg_state.NewMessageReceived) {
        final message = state.message;
        print('ChatScreen: Received new message from user ${message.senderId}');
        print('ChatScreen: Message content: "${message.content}"');

        if (message.senderId == widget.match.matchedUser.id ||
            message.receiverId == widget.match.matchedUser.id) {
          setState(() {
            _messages.add(ChatMessage.fromMessage(message, currentUserId));
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          });
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
      } else if (state is msg_state.MessageSent) {
        print('ChatScreen: Message sent successfully');
      } else if (state is msg_state.MessageSendFailed) {
        print('ChatScreen: Message send failed: ${state.errorMessage}');
      }
    });
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

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Search Messages'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search messages...',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (query) {
              if (query.isNotEmpty) {
                final messageCubit = context.read<MessageCubit>();
                messageCubit.searchMessages(query);
              }
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
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
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog();
            },
          ),
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
      body: BlocListener<MessageCubit, msg_state.MessageState>(
        listener: (context, state) {
          _updateMessagesFromState(state);

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
          }
        },
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<MessageCubit, msg_state.MessageState>(
                builder: (context, state) {
                  if (state is msg_state.MessageLoading) {
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

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
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
                  IconButton(
                    icon: const Icon(Icons.image, color: Colors.blueAccent),
                    onPressed:
                        _isUploadingImage ? null : _showImagePickerOptions,
                  ),
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
                    icon: _isSendingMessage || _isUploadingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: _isSendingMessage || _isUploadingImage
                        ? null
                        : _sendMessage,
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

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final File? localFile;

  const FullScreenImageViewer({
    Key? key,
    required this.imageUrl,
    this.localFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // TODO: Implement image download
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: localFile != null
              ? Image.file(localFile!)
              : Image.network(
                  imageUrl,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 100,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
