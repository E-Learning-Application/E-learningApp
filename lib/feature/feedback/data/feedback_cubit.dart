import 'package:e_learning_app/feature/feedback/model/feedback_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'feedback_state.dart';
import 'feedback_service.dart';

abstract class FeedbackEvent {}

class LoadFeedbacks extends FeedbackEvent {
  final int userId;
  LoadFeedbacks(this.userId);
}

class CreateFeedback extends FeedbackEvent {
  final double rating;
  final String comment;
  final int? feedbackedId;
  CreateFeedback(this.rating, this.comment, {this.feedbackedId});
}

class UpdateFeedback extends FeedbackEvent {
  final Feedback feedback;
  final double newRating;
  final String newComment;
  UpdateFeedback(this.feedback, this.newRating, this.newComment);
}

class DeleteFeedback extends FeedbackEvent {
  final int feedbackId;
  DeleteFeedback(this.feedbackId);
}

class FeedbackCubit extends Cubit<FeedbackState> {
  final FeedbackService _feedbackService;

  FeedbackCubit(this._feedbackService) : super(FeedbackInitial());

  Future<void> loadFeedbacks(int userId) async {
    emit(FeedbackLoading());
    try {
      final feedbacks = await _feedbackService.getAllFeedbacks(userId);
      final averageRating = _feedbackService.calculateAverageRating(feedbacks);
      final ratingDistribution =
          _feedbackService.calculateRatingDistribution(feedbacks);

      emit(FeedbackLoaded(
        feedbacks: feedbacks,
        averageRating: averageRating,
        ratingDistribution: ratingDistribution,
      ));
    } catch (e) {
      emit(FeedbackError('Failed to load feedbacks: ${e.toString()}'));
    }
  }

  Future<void> createFeedback(double rating, String comment,
      {int? feedbackedId}) async {
    if (comment.trim().isEmpty) {
      emit(FeedbackError('Please enter a comment'));
      return;
    }

    emit(FeedbackLoading());
    try {
      final newFeedback = await _feedbackService.createFeedback(rating, comment,
          feedbackedId: feedbackedId);
      emit(FeedbackCreated(newFeedback));
    } catch (e) {
      print('DEBUG: Feedback cubit error: $e');
      String errorMessage = 'Failed to create feedback';

      if (e.toString().contains('500')) {
        errorMessage = 'Server error occurred. Please try again later.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Session expired. Please login again.';
      } else if (e.toString().contains('400')) {
        errorMessage = 'Invalid request. Please check your input.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }

      emit(FeedbackError(errorMessage));
    }
  }

  Future<void> updateFeedback(
      Feedback feedback, double newRating, String newComment) async {
    emit(FeedbackLoading());
    try {
      final updatedFeedback = await _feedbackService.updateFeedback(
        feedback.id,
        newRating,
        newComment,
      );
      emit(FeedbackUpdated(updatedFeedback));
    } catch (e) {
      emit(FeedbackError('Failed to update feedback: ${e.toString()}'));
    }
  }

  Future<void> deleteFeedback(int feedbackId) async {
    emit(FeedbackLoading());
    try {
      await _feedbackService.deleteFeedback(feedbackId);
      emit(FeedbackDeleted(feedbackId));
    } catch (e) {
      emit(FeedbackError('Failed to delete feedback: ${e.toString()}'));
    }
  }

  Future<void> refreshFeedbacks(int userId) async {
    await loadFeedbacks(userId);
  }
}
