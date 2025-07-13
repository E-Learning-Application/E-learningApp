import 'package:e_learning_app/feature/feedback/model/feedback_model.dart';

abstract class FeedbackState {}

class FeedbackInitial extends FeedbackState {}

class FeedbackLoading extends FeedbackState {}

class FeedbackLoaded extends FeedbackState {
  final List<Feedback> feedbacks;
  final double averageRating;
  final Map<int, int> ratingDistribution;

  FeedbackLoaded({
    required this.feedbacks,
    required this.averageRating,
    required this.ratingDistribution,
  });
}

class FeedbackError extends FeedbackState {
  final String message;

  FeedbackError(this.message);
}

class FeedbackCreated extends FeedbackState {
  final Feedback feedback;

  FeedbackCreated(this.feedback);
}

class FeedbackUpdated extends FeedbackState {
  final Feedback feedback;

  FeedbackUpdated(this.feedback);
}

class FeedbackDeleted extends FeedbackState {
  final int feedbackId;

  FeedbackDeleted(this.feedbackId);
}
