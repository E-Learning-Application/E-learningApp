import 'package:e_learning_app/feature/feedback/model/feedback_model.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'package:e_learning_app/core/errors/exceptions.dart';
import 'package:e_learning_app/core/errors/error_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:e_learning_app/core/api/end_points.dart' as api_keys;

class FeedbackService {
  final DioConsumer _dioConsumer;
  final _secureStorage = const FlutterSecureStorage();

  FeedbackService(this._dioConsumer);

  Future<String?> _getAccessToken() async {
    return await _secureStorage.read(key: api_keys.ApiKey.accessToken);
  }

  Future<List<Feedback>> getAllFeedbacks(int userId) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        throw ServerException(
          errModel: ErrorModel(
            status: 401,
            errorMessage: 'Access token not found. Please login again.',
          ),
        );
      }

      final response = await _dioConsumer.get(
        EndPoint.getAllFeedbacks,
        queryParameters: {'userId': userId},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response['data'] != null) {
        final List<dynamic> feedbacksList = response['data'];
        return feedbacksList.map((json) => Feedback.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      throw ServerException(
        errModel: ErrorModel(
          status: 500,
          errorMessage: 'Failed to load feedbacks: ${e.toString()}',
        ),
      );
    }
  }

  Future<Feedback> createFeedback(double rating, String comment,
      {int? feedbackedId}) async {
    try {
      // Validate input
      if (rating < 1.0 || rating > 5.0) {
        throw ServerException(
          errModel: ErrorModel(
            status: 400,
            errorMessage: 'Rating must be between 1.0 and 5.0',
          ),
        );
      }

      if (comment.trim().isEmpty) {
        throw ServerException(
          errModel: ErrorModel(
            status: 400,
            errorMessage: 'Comment cannot be empty',
          ),
        );
      }

      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        throw ServerException(
          errModel: ErrorModel(
            status: 401,
            errorMessage: 'Access token not found. Please login again.',
          ),
        );
      }

      final userIdString =
          await _secureStorage.read(key: api_keys.ApiKey.userId);
      final feedbackerId =
          userIdString != null ? int.parse(userIdString) : null;

      if (feedbackerId == null) {
        throw ServerException(
          errModel: ErrorModel(
            status: 400,
            errorMessage: 'User ID not found. Please login again.',
          ),
        );
      }

      if (feedbackedId == null) {
        throw ServerException(
          errModel: ErrorModel(
            status: 400,
            errorMessage: 'Please specify who you want to give feedback to.',
          ),
        );
      }

      if (feedbackerId == feedbackedId) {
        throw ServerException(
          errModel: ErrorModel(
            status: 400,
            errorMessage:
                'You cannot give feedback to yourself. Please specify a different user.',
          ),
        );
      }

      final request = CreateFeedbackRequest(
        feedbackerId: feedbackerId,
        feedbackedId: feedbackedId,
        rating: rating,
        comment: comment.trim(),
      );

      final response = await _dioConsumer.post(
        EndPoint.createFeedback,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response['data'] != null) {
        return Feedback.fromJson(response['data']);
      }

      throw ServerException(
        errModel: ErrorModel(
          status: 500,
          errorMessage: 'Failed to create feedback: Invalid response',
        ),
      );
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(
        errModel: ErrorModel(
          status: 500,
          errorMessage: 'Failed to create feedback: ${e.toString()}',
        ),
      );
    }
  }

  Future<Feedback> updateFeedback(int id, double rating, String comment) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        throw ServerException(
          errModel: ErrorModel(
            status: 401,
            errorMessage: 'Access token not found. Please login again.',
          ),
        );
      }

      final request = UpdateFeedbackRequest(
        id: id,
        rating: rating,
        comment: comment,
      );

      final response = await _dioConsumer.put(
        EndPoint.updateFeedback,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response['data'] != null) {
        return Feedback.fromJson(response['data']);
      }

      throw ServerException(
        errModel: ErrorModel(
          status: 500,
          errorMessage: 'Failed to update feedback: Invalid response',
        ),
      );
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(
        errModel: ErrorModel(
          status: 500,
          errorMessage: 'Failed to update feedback: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> deleteFeedback(int feedbackId) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        throw ServerException(
          errModel: ErrorModel(
            status: 401,
            errorMessage: 'Access token not found. Please login again.',
          ),
        );
      }

      await _dioConsumer.delete(
        EndPoint.deleteFeedback,
        queryParameters: {'feedbackId': feedbackId},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );
    } catch (e) {
      throw ServerException(
        errModel: ErrorModel(
          status: 500,
          errorMessage: 'Failed to delete feedback: ${e.toString()}',
        ),
      );
    }
  }

  double calculateAverageRating(List<Feedback> feedbacks) {
    if (feedbacks.isEmpty) return 0.0;
    return feedbacks.map((f) => f.rating).reduce((a, b) => a + b) /
        feedbacks.length;
  }

  Map<int, int> calculateRatingDistribution(List<Feedback> feedbacks) {
    final ratingCounts = <int, int>{};
    for (var feedback in feedbacks) {
      final rating = feedback.rating.round();
      ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
    }
    return ratingCounts;
  }
}
