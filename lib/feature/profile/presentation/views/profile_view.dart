import 'dart:io';
import 'package:dio/dio.dart';
import 'package:e_learning_app/core/model/language_model.dart';
import 'package:e_learning_app/feature/profile/data/user_cubit.dart';
import 'package:e_learning_app/feature/profile/data/user_state.dart';
import 'package:e_learning_app/feature/Auth/data/auth_cubit.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'package:e_learning_app/core/service/interest_service.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/feature/language/data/language_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isEditing = false;
  File? _selectedImage;
  User? _currentUser;
  List<Interest> _userInterests = [];
  bool _isLoadingInterests = false;
  bool _hasLoadedInterests = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  void _loadUserData() {
    // Reset interests when loading different user data
    setState(() {
      _hasLoadedInterests = false;
      _userInterests = [];
    });

    if (widget.userId != null) {
      context.read<UserCubit>().getUserById(widget.userId!);
    } else {
      context.read<UserCubit>().getCurrentUserProfile();
    }
  }

  // Test method to manually trigger interests loading
  void _testLoadInterests() {
    final currentUser = context.read<AuthCubit>().currentUser;
    if (currentUser != null) {
      // Reset the flag to allow reloading
      setState(() {
        _hasLoadedInterests = false;
      });
      _loadUserInterests(currentUser.userId);
    }
  }

  Future<void> _loadUserInterests(int userId) async {
    // Prevent multiple calls for the same user
    if (_hasLoadedInterests) {
      print('DEBUG: Interests already loaded, skipping');
      return;
    }

    try {
      setState(() {
        _isLoadingInterests = true;
      });

      final authCubit = context.read<AuthCubit>();
      final token = authCubit.accessToken;
      final currentUser = authCubit.currentUser;

      if (token == null) {
        print('DEBUG: No access token available for loading interests');
        return;
      }

      // Only load interests if viewing current user's profile
      // or if we have admin access (for future implementation)
      if (currentUser?.userId != userId) {
        print('DEBUG: Can only view interests for current user');
        setState(() {
          _userInterests = [];
          _hasLoadedInterests = true;
        });
        return;
      }

      final dioConsumer = DioConsumer(dio: Dio());
      final interestService = InterestService(dioConsumer: dioConsumer);

      // Use the current user's interests endpoint since backend doesn't support user ID parameter
      final response = await interestService.getUserInterests(
        accessToken: token,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> interestsData = response.data;
        print('DEBUG: Raw interests data: $interestsData');

        // Handle the flattened UserInterest structure from backend
        final interests = interestsData
            .map((item) {
              print('DEBUG: Processing interest item: $item');
              if (item is Map<String, dynamic>) {
                // Check if this is a flattened UserInterest object (from backend)
                if (item.containsKey('interestName') &&
                    item.containsKey('interestId')) {
                  print('DEBUG: Found flattened UserInterest object: $item');
                  return Interest(
                    id: item['interestId'] ?? 0,
                    name: item['interestName'] ?? '',
                    description: null,
                  );
                }
                // Check if this is a UserInterest object with nested interest
                else if (item.containsKey('interest') &&
                    item['interest'] != null) {
                  print(
                      'DEBUG: Found UserInterest with nested interest: ${item['interest']}');
                  return Interest.fromJson(item['interest']);
                } else {
                  // Direct Interest object
                  print('DEBUG: Found direct Interest object: $item');
                  return Interest.fromJson(item);
                }
              }
              return null;
            })
            .where((interest) => interest != null)
            .cast<Interest>()
            .toList();

        print(
            'DEBUG: Parsed interests: ${interests.map((i) => i.name).toList()}');
        setState(() {
          _userInterests = interests;
          _hasLoadedInterests = true;
        });
      } else {
        print('DEBUG: Failed to load user interests: ${response.message}');
        setState(() {
          _hasLoadedInterests = true;
        });
      }
    } catch (e) {
      print('DEBUG: Error loading user interests: $e');
      setState(() {
        _hasLoadedInterests = true;
      });
    } finally {
      setState(() {
        _isLoadingInterests = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return; // User cancelled

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      // Handle image picker errors gracefully
      String errorMessage = 'Failed to pick image';

      if (e.toString().contains('channel-error')) {
        errorMessage =
            'Image picker is not available. Please try again or restart the app.';
      } else if (e.toString().contains('permission')) {
        errorMessage =
            'Permission denied. Please grant storage permission in app settings.';
      } else if (e.toString().contains('cancelled')) {
        // User cancelled, no need to show error
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing && _currentUser != null) {
        _usernameController.text = _currentUser!.username;
        _bioController.text = _currentUser!.bio ?? '';
      }
      if (!_isEditing) {
        _selectedImage = null;
      }
    });
  }

  void _updateProfile() {
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    // Check if anything has changed
    final bool usernameChanged = username != (_currentUser?.username ?? "");
    final bool bioChanged = bio != (_currentUser?.bio ?? "");
    final bool imageChanged = _selectedImage != null;

    if (!usernameChanged && !bioChanged && !imageChanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes were Made')),
      );
      setState(() {
        _isEditing = false;
        _selectedImage = null;
      });
      return;
    }

    context.read<UserCubit>().updateUserProfile(
          username: username, // Always pass the username (current or updated)
          bio: bioChanged ? bio : null,
          image: imageChanged ? _selectedImage : null,
        );

    setState(() {
      _isEditing = false;
      _selectedImage = null;
    });
  }

  void _showPasswordUpdateDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    // State variables for password visibility
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current Password Field
              TextField(
                controller: currentPasswordController,
                obscureText: !showCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showCurrentPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        showCurrentPassword = !showCurrentPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // New Password Field
              TextField(
                controller: newPasswordController,
                obscureText: !showNewPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showNewPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        showNewPassword = !showNewPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Confirm New Password Field
              TextField(
                controller: confirmPasswordController,
                obscureText: !showConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        showConfirmPassword = !showConfirmPassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (newPasswordController.text.isEmpty ||
                    currentPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }

                final request = UpdatePasswordRequest(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                  confirmNewPassword: confirmPasswordController.text,
                );
                context.read<UserCubit>().updatePassword(request);
                Navigator.of(context).pop();
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // Get current user ID if not provided
              final userId = widget.userId ??
                  context.read<AuthCubit>().currentUser?.userId;
              if (userId != null) {
                context.read<UserCubit>().deleteUser(userId);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  bool _isCurrentUser() {
    if (widget.userId == null) return true; // No userId means current user
    final currentUserId = context.read<AuthCubit>().currentUser?.userId;
    return widget.userId == currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: MultiBlocListener(
          listeners: [
            BlocListener<UserCubit, UserState>(
              listener: (context, state) {
                if (state is UserSuccess) {
                  if (state.message != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.message!)),
                    );
                  }
                  // Reload user data after successful update
                  if (state.message != null &&
                      (state.message!.contains('updated') ||
                          state.message!.contains('Password updated'))) {
                    _loadUserData();
                  }
                } else if (state is UserError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );

                  if (state.message.contains('Unauthorized') ||
                      state.message.contains('login again')) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ],
          child: BlocBuilder<UserCubit, UserState>(
            builder: (context, state) {
              if (state is UserLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              User? user;
              if (state is UserSuccess && state.data is User) {
                user = state.data as User;
                _currentUser = user;

                if (!_isEditing) {
                  _usernameController.text = user.username;
                  _bioController.text = user.bio ?? '';
                }

                // Load user interests when user data is available
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadUserInterests(user!.id);
                });
              }

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildProfileForm(user),
                      const SizedBox(height: 24),
                      if (user?.languagePreferences != null)
                        _buildLanguagePreferences(user!.languagePreferences!),
                      const SizedBox(height: 24),
                      _buildUserInterests(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Profile Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_isCurrentUser())
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _toggleEdit();
                    break;
                  case 'password':
                    _showPasswordUpdateDialog();
                    break;
                  case 'delete':
                    _showDeleteDialog();
                    break;
                  case 'refresh':
                    _loadUserData();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(_isEditing ? Icons.cancel : Icons.edit),
                      const SizedBox(width: 8),
                      Text(_isEditing ? 'Cancel Edit' : 'Edit Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'password',
                  child: Row(
                    children: [
                      Icon(Icons.lock),
                      SizedBox(width: 8),
                      Text('Change Password'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Refresh'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Account',
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(User? user) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.blue[100],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: _selectedImage != null
                ? Image.file(_selectedImage!, fit: BoxFit.cover)
                : user?.imagePath != null
                    ? Image.network(
                        '${EndPoint.baseUrl}${user!.imagePath!}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person,
                                size: 60, color: Colors.white),
                      )
                    : const Icon(Icons.person, size: 60, color: Colors.white),
          ),
        ),
        if (_isEditing && _isCurrentUser())
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileForm(User? user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile image on the left
        _buildProfileAvatar(user),
        const SizedBox(width: 20),

        // Username and bio on the right
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Username field
              _isEditing && _isCurrentUser()
                  ? TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    )
                  : Text(
                      user?.username ?? 'Username not available',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

              const SizedBox(height: 16),

              // Bio field
              _isEditing && _isCurrentUser()
                  ? TextField(
                      controller: _bioController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.info),
                      ),
                    )
                  : Text(
                      user?.bio ?? 'No bio available',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                    ),

              if (_isEditing && _isCurrentUser()) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        onPressed: _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 40,
                      child: OutlinedButton(
                        onPressed: _toggleEdit,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Icon(Icons.close, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguagePreferences(List<LanguagePreference> preferences) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Language Preferences',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...preferences
            .map((pref) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        pref.isLearning ? Icons.school : Icons.language,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pref.language.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${pref.proficiencyLevel} • ${pref.isLearning ? 'Learning' : 'Known'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ],
    );
  }

  Widget _buildUserInterests() {
    final currentUser = context.read<AuthCubit>().currentUser;
    final isCurrentUser =
        currentUser?.userId == widget.userId || widget.userId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Interests',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingInterests)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (!isCurrentUser)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: const Center(
              child: Text(
                'Interests are only visible to the profile owner',
                style: TextStyle(
                  color: Colors.blue,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else if (_userInterests.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Text(
                'No interests found',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          ..._userInterests
              .map((interest) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            interest.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
      ],
    );
  }
}
