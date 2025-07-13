// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'package:e_learning_app/feature/feedback/model/feedback_model.dart'
    as feedback_state;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/feedback_cubit.dart';
import '../../data/feedback_state.dart' as feedback_state;

class FeedbackView extends StatefulWidget {
  const FeedbackView({super.key});

  @override
  _FeedbackViewState createState() => _FeedbackViewState();
}

class _FeedbackViewState extends State<FeedbackView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  double _currentRating = 5.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<FeedbackCubit>().loadFeedbacks(1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Feedback Manager',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Color(0xFF6366F1),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.list_alt), text: 'All Feedback'),
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Create'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Analytics'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: BlocConsumer<FeedbackCubit, feedback_state.FeedbackState>(
        listener: (context, state) {
          if (state is feedback_state.FeedbackError) {
            _showErrorSnackbar(state.message);
          } else if (state is feedback_state.FeedbackCreated) {
            _showSuccessSnackbar('Feedback created successfully!');
            _tabController.animateTo(0); // Switch to feedback list
            _resetForm();
            context.read<FeedbackCubit>().refreshFeedbacks(1);
          } else if (state is feedback_state.FeedbackUpdated) {
            _showSuccessSnackbar('Feedback updated successfully!');
            context.read<FeedbackCubit>().refreshFeedbacks(1);
          } else if (state is feedback_state.FeedbackDeleted) {
            _showSuccessSnackbar('Feedback deleted successfully!');
            context.read<FeedbackCubit>().refreshFeedbacks(1);
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  _buildFeedbackList(state),
                  _buildCreateFeedback(),
                  _buildAnalytics(state),
                ],
              ),
              if (state is feedback_state.FeedbackLoading)
                Container(
                  color: Colors.black26,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF6366F1)),
                          SizedBox(height: 16),
                          Text('Processing...', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeedbackList(feedback_state.FeedbackState state) {
    if (state is feedback_state.FeedbackLoaded) {
      return RefreshIndicator(
        onRefresh: () => context.read<FeedbackCubit>().refreshFeedbacks(1),
        color: Color(0xFF6366F1),
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: state.feedbacks.length,
          itemBuilder: (context, index) {
            final feedback = state.feedbacks[index];
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: Color(0xFF6366F1),
                  child: Text(
                    feedback.userId.toString(),
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        feedback.comment,
                        style: TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            _getRatingColor(feedback.rating).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: _getRatingColor(feedback.rating),
                          ),
                          SizedBox(width: 4),
                          Text(
                            feedback.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: _getRatingColor(feedback.rating),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
                    Text(
                      'User ID: ${feedback.userId}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _formatDate(feedback.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(feedback);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(feedback.id);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return Center(child: Text('No feedbacks available'));
  }

  Widget _buildCreateFeedback() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Feedback',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Give feedback to another user',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Rating',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentRating = (index + 1).toDouble();
                              });
                            },
                            child: Icon(
                              Icons.star,
                              size: 40,
                              color: index < _currentRating
                                  ? Colors.amber
                                  : Colors.grey[300],
                            ),
                          );
                        }),
                      ),
                      SizedBox(height: 12),
                      Slider(
                        value: _currentRating,
                        min: 1.0,
                        max: 5.0,
                        divisions: 8,
                        label: _currentRating.toStringAsFixed(1),
                        activeColor: Color(0xFF6366F1),
                        onChanged: (value) {
                          setState(() {
                            _currentRating = value;
                          });
                        },
                      ),
                      Text(
                        'Rating: ${_currentRating.toStringAsFixed(1)}/5.0',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Comment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts about the user...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    ),
                    filled: true,
                    fillColor: Color(0xFFF9FAFB),
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      // For testing, give feedback to user ID 2 (different from current user)
                      context.read<FeedbackCubit>().createFeedback(
                            _currentRating,
                            _commentController.text.trim(),
                            feedbackedId: 2, // Give feedback to user ID 2
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Submit User Feedback',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAnalytics(feedback_state.FeedbackState state) {
    if (state is feedback_state.FeedbackLoaded) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsCard(
                    'Total Feedback',
                    state.feedbacks.length.toString(),
                    Icons.feedback,
                    Color(0xFF6366F1),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildAnalyticsCard(
                    'Average Rating',
                    state.averageRating.toStringAsFixed(1),
                    Icons.star,
                    Colors.amber,
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Rating Distribution
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rating Distribution',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 20),
                  ...List.generate(5, (index) {
                    final rating = 5 - index;
                    final count = state.ratingDistribution[rating] ?? 0;
                    final percentage = state.feedbacks.isEmpty
                        ? 0.0
                        : (count / state.feedbacks.length) * 100;

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Row(
                            children: List.generate(
                                rating,
                                (i) => Icon(
                                      Icons.star,
                                      size: 16,
                                      color: Colors.amber,
                                    )),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Color(0xFFE5E7EB),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getRatingColor(rating.toDouble()),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            '$count (${percentage.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Center(child: Text('No analytics available'));
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 32,
            color: color,
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(feedback_state.Feedback feedback) {
    final commentController = TextEditingController(text: feedback.comment);
    double editRating = feedback.rating;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rating:'),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        editRating = (index + 1).toDouble();
                      });
                    },
                    child: Icon(
                      Icons.star,
                      size: 32,
                      color:
                          index < editRating ? Colors.amber : Colors.grey[300],
                    ),
                  );
                }),
              ),
              SizedBox(height: 16),
              Text('Comment:'),
              SizedBox(height: 8),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter your comment...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<FeedbackCubit>().updateFeedback(
                    feedback, editRating, commentController.text.trim());
                Navigator.pop(context);
              },
              child: Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int feedbackId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Feedback'),
        content: Text(
            'Are you sure you want to delete this feedback? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<FeedbackCubit>().deleteFeedback(feedbackId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _commentController.clear();
    _currentRating = 5.0;
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 3.5) return Colors.orange;
    if (rating >= 2.5) return Colors.amber;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
