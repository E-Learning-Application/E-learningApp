import 'package:flutter/material.dart';
import 'package:e_learning_app/core/model/user_dto.dart';

class UserSelectionScreen extends StatefulWidget {
  final Function(UserDto) onUserSelected;

  const UserSelectionScreen({
    Key? key,
    required this.onUserSelected,
  }) : super(key: key);

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<UserDto> _allUsers = [];
  final List<UserDto> _filteredUsers = [];
  bool _isLoading = false;

  String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    const baseUrl = 'https://elearningproject.runasp.net';
    return '$baseUrl$path';
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers() {
    setState(() {
      _isLoading = true;
    });

    // TODO: Replace with actual API call to get users
    // For now, we'll use mock data
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _allUsers.clear();
          _allUsers.addAll([
            UserDto(
              id: 1,
              username: 'John Doe',
              profilePicture: null,
              languages: ['English', 'Spanish'],
            ),
            UserDto(
              id: 2,
              username: 'Jane Smith',
              profilePicture: 'https://example.com/jane.jpg',
              languages: ['English', 'French'],
            ),
            UserDto(
              id: 3,
              username: 'Mike Johnson',
              profilePicture: null,
              languages: ['English', 'German'],
            ),
            UserDto(
              id: 4,
              username: 'Sarah Wilson',
              profilePicture: 'https://example.com/sarah.jpg',
              languages: ['English', 'Italian'],
            ),
            UserDto(
              id: 5,
              username: 'David Brown',
              profilePicture: null,
              languages: ['English', 'Portuguese'],
            ),
          ]);
          _filteredUsers.clear();
          _filteredUsers.addAll(_allUsers);
          _isLoading = false;
        });
      }
    });
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers.clear();
      if (query.isEmpty) {
        _filteredUsers.addAll(_allUsers);
      } else {
        _filteredUsers.addAll(
          _allUsers
              .where((user) => user.username.toLowerCase().contains(query)),
        );
      }
    });
  }

  Widget _buildUserItem(UserDto user) {
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: user.profilePicture != null
            ? NetworkImage(getFullImageUrl(user.profilePicture!))
            : null,
        child: user.profilePicture == null
            ? Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        user.username,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: user.languages != null && user.languages!.isNotEmpty
          ? Text(
              'Languages: ${user.languages!.join(', ')}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.chat_bubble_outline),
        onPressed: () {
          widget.onUserSelected(user);
          Navigator.of(context).pop();
        },
      ),
      onTap: () {
        widget.onUserSelected(user);
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select User to Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          // User list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No users available'
                                  : 'No users found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserItem(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
