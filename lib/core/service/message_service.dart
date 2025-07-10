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

      log('getChatList response: $response');

      if (response is List) {
        return response.map((json) => ChatSummary.fromJson(json)).toList();
      } else if (response is Map<String, dynamic>) {
        if (response.containsKey('data') && response['data'] is List) {
          final List<dynamic> data = response['data'];
          return data.map((json) => ChatSummary.fromJson(json)).toList();
        } else if (response.containsKey('chats') && response['chats'] is List) {
          final List<dynamic> chats = response['chats'];
          return chats.map((json) => ChatSummary.fromJson(json)).toList();
        }
      }

      throw Exception(
          'Invalid response format: Expected List or Map with data/chats key');
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

      log('getChatHistory response: $response');

      if (response is List) {
        return response.map((json) => Message.fromJson(json)).toList();
      } else if (response is Map<String, dynamic>) {
        final possibleKeys = ['messages', 'data', 'items', 'results'];

        for (final key in possibleKeys) {
          if (response.containsKey(key) && response[key] is List) {
            final List<dynamic> messages = response[key];
            return messages.map((json) => Message.fromJson(json)).toList();
          }
        }
        if (response.containsKey('pagination') ||
            response.containsKey('total')) {
          return [];
        }
      }

      throw Exception(
          'Invalid response format: Expected List or Map with messages/data key');
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

      log('searchMessages response: $response');

      if (response is List) {
        return response.map((json) => Message.fromJson(json)).toList();
      } else if (response is Map<String, dynamic>) {
        if (response.containsKey('results') && response['results'] is List) {
          final List<dynamic> results = response['results'];
          return results.map((json) => Message.fromJson(json)).toList();
        } else if (response.containsKey('data') && response['data'] is List) {
          final List<dynamic> data = response['data'];
          return data.map((json) => Message.fromJson(json)).toList();
        }
      }

      throw Exception(
          'Invalid response format: Expected List or Map with results/data key');
    } catch (e) {
      log('Error searching messages: $e');
      throw Exception('Failed to search messages: $e');
    }
  }

  Future<Message?> sendMessage(SendMessageRequest request) async {
    try {
      log('REST API sending not supported by server. Messages must be sent via SignalR.');
      return null;
    } catch (e) {
      log('Error sending message via REST: $e');
      return null;
    }
  }

  Future<bool> markMessageAsRead(int messageId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dioConsumer.patch(
        '${EndPoint.markMessageAsRead}/$messageId',
        options: options,
      );

      log('markMessageAsRead response: $response');
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
      final response = await _dioConsumer.patch(
        EndPoint.markAllMessagesAsRead,
        data: {'withUserId': withUserId},
        options: options,
      );

      log('markAllMessagesAsRead response: $response');
      return true;
    } catch (e) {
      log('Error marking all messages as read: $e');
      return false;
    }
  }

  Future<bool> deleteMessage(int messageId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dioConsumer.delete(
        '${EndPoint.deleteMessage}/$messageId',
        options: options,
      );

      log('deleteMessage response: $response');
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

      log('getMessageById response: $response');

      if (response is Map<String, dynamic>) {
        if (response.containsKey('message')) {
          return Message.fromJson(response['message']);
        } else if (response.containsKey('data')) {
          return Message.fromJson(response['data']);
        } else {
          // Try to parse the response directly
          return Message.fromJson(response);
        }
      }

      throw Exception(
          'Invalid response format: Expected Map with message data');
    } catch (e) {
      log('Error getting message by ID $messageId: $e');
      return null;
    }
  }

  bool _isValidResponse(dynamic response) {
    if (response == null) return false;

    if (response is List) return true;

    if (response is Map<String, dynamic>) {
      final commonKeys = ['data', 'messages', 'results', 'items', 'message'];
      return commonKeys.any((key) => response.containsKey(key));
    }

    return false;
  }

  Future<bool> testApiConnectivity() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dioConsumer.get(
        EndPoint.getChatList,
        options: options,
      );

      log('API connectivity test response: $response');
      return _isValidResponse(response);
    } catch (e) {
      log('API connectivity test failed: $e');
      return false;
    }
  }
}
