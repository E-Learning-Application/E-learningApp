import 'dart:developer';
import 'package:e_learning_app/core/model/message_model.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

class MessageService {
  final DioConsumer _dioConsumer;
  final FlutterSecureStorage _secureStorage;

  MessageService({
    required DioConsumer dioConsumer,
    FlutterSecureStorage? secureStorage,
  })  : _dioConsumer = dioConsumer,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final accessToken = await _secureStorage.read(key: ApiKey.accessToken);
    return Options(
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  Future<bool> _isAuthenticated() async {
    final accessToken = await _secureStorage.read(key: ApiKey.accessToken);
    return accessToken != null && accessToken.isNotEmpty;
  }

  Future<List<ChatSummary>> getChatList() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dioConsumer.get(
        EndPoint.getChatList,
        options: options,
      );

      if (response is List) {
        return response.map((json) => ChatSummary.fromJson(json)).toList();
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      log('Error getting chat list: $e');
      throw Exception('Failed to load chat list: $e');
    }
  }

  Future<List<Message>> getChatHistory({
    required int withUserId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      if (!await _isAuthenticated()) {
        throw Exception('User not authenticated');
      }

      final options = await _getAuthOptions();
      final response = await _dioConsumer.get(
        EndPoint.getChatWith,
        queryParameters: {
          'withUser': withUserId,
          'page': page,
          'pageSize': pageSize,
        },
        options: options,
      );

      if (response is List) {
        return response.map((json) => Message.fromJson(json)).toList();
      } else if (response is Map<String, dynamic> &&
          response.containsKey('messages')) {
        final List<dynamic> messages = response['messages'];
        return messages.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      log('Error getting chat history: $e');
      throw Exception('Failed to load chat history: $e');
    }
  }

  Future<List<Message>> searchMessages(String query) async {
    try {
      if (!await _isAuthenticated()) {
        throw Exception('User not authenticated');
      }

      final options = await _getAuthOptions();
      final response = await _dioConsumer.get(
        EndPoint.searchMessages,
        queryParameters: {'q': query},
        options: options,
      );

      if (response is List) {
        return response.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      log('Error searching messages: $e');
      throw Exception('Failed to search messages: $e');
    }
  }

  Future<Message?> sendMessage(SendMessageRequest request) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dioConsumer.post(
        EndPoint.sendMessage,
        data: request.toJson(),
        options: options,
      );

      if (response is Map<String, dynamic>) {
        return Message.fromJson(response);
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      log('Error sending message via REST: $e');
      return null;
    }
  }

  Future<bool> markMessageAsRead(int messageId) async {
    try {
      final options = await _getAuthOptions();
      await _dioConsumer.patch(
        '${EndPoint.markMessageAsRead}/$messageId',
        options: options,
      );
      return true;
    } catch (e) {
      log('Error marking message as read: $e');
      return false;
    }
  }

  Future<bool> markAllMessagesAsRead(int withUserId) async {
    try {
      if (!await _isAuthenticated()) {
        throw Exception('User not authenticated');
      }

      final options = await _getAuthOptions();
      await _dioConsumer.patch(
        EndPoint.markAllMessagesAsRead,
        data: {'withUserId': withUserId},
        options: options,
      );
      return true;
    } catch (e) {
      log('Error marking all messages as read: $e');
      return false;
    }
  }

  Future<bool> deleteMessage(int messageId) async {
    try {
      final options = await _getAuthOptions();
      await _dioConsumer.delete(
        '${EndPoint.deleteMessage}/$messageId',
        options: options,
      );
      return true;
    } catch (e) {
      log('Error deleting message: $e');
      return false;
    }
  }

  /// Get specific message by ID
  Future<Message?> getMessageById(int messageId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dioConsumer.get(
        '${EndPoint.getMessageById}/$messageId',
        options: options,
      );

      if (response is Map<String, dynamic>) {
        return Message.fromJson(response);
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      log('Error getting message by ID $messageId: $e');
      return null;
    }
  }
}
