import 'package:e_learning_app/feature/messages/data/message_cubit.dart';
import 'package:e_learning_app/feature/messages/data/message_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/core/model/message_model.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late MessageCubit _messageCubit;

  @override
  void initState() {
    super.initState();
    _messageCubit = context.read<MessageCubit>();
    // Load chat list when screen initializes
    _messageCubit.loadChatList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(),

            // Chat List Content
            Expanded(
              child: BlocConsumer<MessageCubit, MessageState>(
                listener: (context, state) {
                  // Handle state changes that require UI feedback
                  if (state is MessageError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else if (state is MessageOperationSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is MessageLoading) {
                    return _buildLoadingState();
                  } else if (state is ChatListEmpty) {
                    return _buildEmptyState();
                  } else if (state is ChatListLoaded) {
                    return _buildChatList(state.chats, state.totalUnreadCount);
                  } else if (state is MessageError) {
                    return _buildErrorState(state.message);
                  }

                  // Default empty state
                  return _buildEmptyState();
                },
              ),
            ),
          ],
        ),
      ),
      // Floating Action Button to start new chat
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to user selection or new chat screen
          _showNewChatDialog();
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          const Text(
            'Messages',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Unread count badge
          BlocBuilder<MessageCubit, MessageState>(
            buildWhen: (previous, current) =>
                current is ChatListLoaded || current is UnreadCountUpdated,
            builder: (context, state) {
              int unreadCount = 0;
              if (state is ChatListLoaded) {
                unreadCount = state.totalUnreadCount;
              } else if (state is UnreadCountUpdated) {
                unreadCount = state.count;
              }

              if (unreadCount > 0) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(width: 8),
          // Refresh button
          IconButton(
            onPressed: () {
              _messageCubit.loadChatList();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _messageCubit.loadChatList();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Container(
            width: 240,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Colors.grey[300],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No chats yet!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _showNewChatDialog();
            },
            child: const Text(
              'Start chatting',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<ChatSummary> chats, int totalUnreadCount) {
    return RefreshIndicator(
      onRefresh: () async {
        _messageCubit.loadChatList();
      },
      child: ListView.builder(
        itemCount: chats.length,
        padding: const EdgeInsets.only(top: 8),
        itemBuilder: (context, index) {
          final chat = chats[index];
          return _buildChatItem(chat);
        },
      ),
    );
  }

  Widget _buildChatItem(ChatSummary chat) {
    return Dismissible(
      key: Key('chat_${chat.userId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        // Show confirmation dialog
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Chat'),
            content: Text(
                'Are you sure you want to delete this chat with ${chat.userName}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        // Handle chat deletion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat with ${chat.userName} deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // Implement undo functionality
              },
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () {
          // Navigate to individual chat screen
          _navigateToChat(chat);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Avatar with online status
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: chat.profileImage != null
                        ? NetworkImage(chat.profileImage!)
                        : null,
                    child: chat.profileImage == null
                        ? Text(
                            chat.userName.isNotEmpty
                                ? chat.userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  // Online status indicator
                  if (chat.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Message content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        // Time
                        Text(
                          _formatTime(chat.lastMessageTime),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: BlocBuilder<MessageCubit, MessageState>(
                            buildWhen: (previous, current) =>
                                current is UserOnlineStatusChanged &&
                                current.userId == chat.userId,
                            builder: (context, state) {
                              bool isTyping = false;
                              if (state is UserOnlineStatusChanged) {
                                isTyping =
                                    _messageCubit.isUserTyping(chat.userId);
                              }

                              return Text(
                                isTyping ? 'typing...' : chat.lastMessage,
                                style: TextStyle(
                                  color:
                                      isTyping ? Colors.blue : Colors.grey[600],
                                  fontSize: 12,
                                  fontStyle: isTyping
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                        // Unread count badge
                        if (chat.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              chat.unreadCount > 99
                                  ? '99+'
                                  : chat.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  void _navigateToChat(ChatSummary chat) {
    // Navigate to individual chat screen
    // You'll need to implement this navigation based on your routing setup
    Navigator.of(context).pushNamed(
      '/chat',
      arguments: {
        'userId': chat.userId,
        'userName': chat.userName,
        'profileImage': chat.profileImage,
      },
    );
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Chat'),
        content: const Text('Feature to search and select users to chat with.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to user selection screen
            },
            child: const Text('Select User'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up when leaving the screen
    _messageCubit.clearCurrentChat();
    super.dispose();
  }
}
