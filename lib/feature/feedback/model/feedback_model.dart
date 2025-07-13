class Feedback {
  final int id;
  final int feedbackerId;
  final int feedbackedId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  Feedback({
    required this.id,
    required this.feedbackerId,
    required this.feedbackedId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['id'] ?? json['Id'] ?? 0,
      feedbackerId: json['feedbackerId'] ?? json['FeedbackerId'] ?? 0,
      feedbackedId: json['feedbackedId'] ?? json['FeedbackedId'] ?? 0,
      rating: (json['rating'] ?? json['Rating'] ?? 0.0).toDouble(),
      comment: json['comment'] ?? json['Comment'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'feedbackerId': feedbackerId,
      'feedbackedId': feedbackedId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  int get userId => feedbackerId;
}

class CreateFeedbackRequest {
  final int feedbackerId;
  final int feedbackedId;
  final double rating;
  final String comment;

  CreateFeedbackRequest({
    required this.feedbackerId,
    required this.feedbackedId,
    required this.rating,
    required this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'FeedbackerId': feedbackerId,
      'FeedbackedId': feedbackedId,
      'Rating': rating,
      'Comment': comment,
    };
  }
}

class UpdateFeedbackRequest {
  final int id;
  final double rating;
  final String comment;

  UpdateFeedbackRequest({
    required this.id,
    required this.rating,
    required this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Rating': rating,
      'Comment': comment,
    };
  }
}
