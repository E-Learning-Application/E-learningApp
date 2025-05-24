
import 'package:flutter/material.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // Toggle this to switch between empty and filled chat list
  bool _hasChats = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                children: const [
                  Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Show either empty state or chat list
            Expanded(
              child: _hasChats ? _buildChatList() : _buildEmptyState(),
            ),
          ],
        ),
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
            'no chats yet!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // Start a new chat action
            },
            child: const Text(
              'start chating',
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

  Widget _buildChatList() {
    final List<Map<String, dynamic>> chats = [
      {
        'name': 'Blake Clarke',
        'message': 'Hello!',
        'time': '12:00 pm',
      },
      {
        'name': 'Lewis Moss',
        'message': 'Excited to connect with ever...',
        'time': '12:00 pm',
      },
      {
        'name': 'Rosemary Rivera',
        'message': 'see you next time',
        'time': '12:00 pm',
      },
      {
        'name': 'Leland Vega',
        'message': 'thats cool',
        'time': '12:00 pm',
      },
      {
        'name': 'Andrea Vargas',
        'message': 'Hello! Excited to connect with ever...',
        'time': '12:00 pm',
      },
      {
        'name': 'Maurice Craig',
        'message': 'well well well...',
        'time': '12:00 pm',
      },
    ];

    return ListView.builder(
      itemCount: chats.length,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (context, index) {
        final chat = chats[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                child: Text(
                  chat['name'][0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Message content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat['message'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Time
              Text(
                chat['time'],
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
