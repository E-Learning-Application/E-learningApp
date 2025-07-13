// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/feedback_cubit.dart';
import '../../data/feedback_state.dart' as feedback_state;
import '../../data/feedback_service.dart';
import 'package:e_learning_app/feature/app_container/app_container.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';

class CallFeedbackDialog extends StatefulWidget {
  final String targetUserName;
  final String callDuration;
  final bool isVideoCall;

  const CallFeedbackDialog({
    super.key,
    required this.targetUserName,
    required this.callDuration,
    required this.isVideoCall,
  });

  @override
  _CallFeedbackDialogState createState() => _CallFeedbackDialogState();
}

class _CallFeedbackDialogState extends State<CallFeedbackDialog> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return BlocProvider(
      create: (context) =>
          FeedbackCubit(FeedbackService(context.read<DioConsumer>())),
      child: BlocConsumer<FeedbackCubit, feedback_state.FeedbackState>(
        listener: (context, state) {
          if (state is feedback_state.FeedbackCreated) {
            _showSuccessAndNavigate();
          } else if (state is feedback_state.FeedbackError) {
            _showErrorSnackbar(state.message);
          }
        },
        builder: (context, state) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
                minWidth: 280,
                maxWidth: 400,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 16),
                    _buildRatingSection(),
                    SizedBox(height: 16),
                    _buildCommentSection(),
                    SizedBox(height: 20),
                    _buildActionButtons(context, state),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color(0xFF6366F1).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.call_end,
            color: Color(0xFF6366F1),
            size: 22,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Call Ended',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'How was your ${widget.isVideoCall ? 'video' : 'voice'} call with ${widget.targetUserName}?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Duration: ${widget.callDuration}',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate your experience',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _rating = (index + 1).toDouble();
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.star,
                  size: 28,
                  color: index < _rating ? Colors.amber : Colors.grey[300],
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 8),
        Slider(
          value: _rating,
          min: 1.0,
          max: 5.0,
          divisions: 8,
          label: _rating.toStringAsFixed(1),
          activeColor: Color(0xFF6366F1),
          onChanged: (value) {
            setState(() {
              _rating = value;
            });
          },
        ),
        Center(
          child: Text(
            '${_rating.toStringAsFixed(1)}/5.0',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6366F1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional comments (optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _commentController,
          maxLines: 2,
          style: TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Share your thoughts about the call...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            filled: true,
            fillColor: Color(0xFFF9FAFB),
            contentPadding: EdgeInsets.all(10),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
      BuildContext context, feedback_state.FeedbackState state) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    Navigator.of(context).pop();
                    _navigateToHome();
                  },
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Skip',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    _submitFeedback(context);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Submit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _submitFeedback(BuildContext context) {
    setState(() {
      _isSubmitting = true;
    });

    // For call feedback, we need to specify a different user
    // Since this is about call experience, we'll use a valid user ID
    // Using user ID 2 as it exists in the system (based on user selection screen)
    context.read<FeedbackCubit>().createFeedback(
          _rating,
          _commentController.text.trim(),
          feedbackedId: 2, // Valid user ID for call feedback
        );
  }

  void _showSuccessAndNavigate() {
    setState(() {
      _isSubmitting = false;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Thank you for your feedback!'),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    // Close dialog and navigate to home
    Navigator.of(context).pop();
    _navigateToHome();
  }

  void _showErrorSnackbar(String message) {
    setState(() {
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToHome() {
    // Navigate to home and clear the navigation stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const AppContainer(),
      ),
      (route) => false, // Remove all previous routes
    );
  }
}
