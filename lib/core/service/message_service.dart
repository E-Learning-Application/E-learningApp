import 'dart:convert';
import 'dart:developer';
import 'package:e_learning_app/core/model/message_model.dart';
import 'package:http/http.dart' as http;

class MessageService {
  final ApiClient _apiClient;

  MessageService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // Get all messages for current user
  Future<List<Message>> getAllMessages() async {
    try {
      final response = await _apiClient.get('/api/messages');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      log('Error getting all messages: $e');
      throw Exception('Failed to load messages: $e');
    }
  }

  // Get chat list (recent chats)
  Future<List<ChatSummary>> getChatList() async {
    try {
      final response = await _apiClient.get('/api/messages/list');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ChatSummary.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load chat list: ${response.statusCode}');
      }
    } catch (e) {
      log('Error getting chat list: $e');
      throw Exception('Failed to load chat list: $e');
    }
  }

  // Get chat messages with specific user
  Future<List<Message>> getChatWith(int withUserId) async {
    try {
      final response =
          await _apiClient.get('/api/messages/chat?withUser=$withUserId');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load chat: ${response.statusCode}');
      }
    } catch (e) {
      log('Error getting chat with user $withUserId: $e');
      throw Exception('Failed to load chat: $e');
    }
  }

  // Get specific message by ID
  Future<Message> getMessageById(int messageId) async {
    try {
      final response = await _apiClient.get('/api/messages/$messageId');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Message.fromJson(data);
      } else {
        throw Exception('Failed to load message: ${response.statusCode}');
      }
    } catch (e) {
      log('Error getting message by ID $messageId: $e');
      throw Exception('Failed to load message: $e');
    }
  }

  // Get unread messages count
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.get('/api/messages/unread/count');

      if (response.statusCode == 200) {
        return json.decode(response.body) as int;
      } else {
        throw Exception('Failed to load unread count: ${response.statusCode}');
      }
    } catch (e) {
      log('Error getting unread count: $e');
      throw Exception('Failed to load unread count: $e');
    }
  }

  // Get last message with specific user
  Future<Message?> getLastMessageWith(int withUserId) async {
    try {
      final response =
          await _apiClient.get('/api/messages/last?withUser=$withUserId');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isNotEmpty && responseBody != 'null') {
          final Map<String, dynamic> data = json.decode(responseBody);
          return Message.fromJson(data);
        }
        return null;
      } else {
        throw Exception('Failed to load last message: ${response.statusCode}');
      }
    } catch (e) {
      log('Error getting last message with user $withUserId: $e');
      return null;
    }
  }

  // Mark message as read
  Future<bool> markMessageAsRead(int messageId) async {
    try {
      final response = await _apiClient.patch('/api/messages/read/$messageId');

      return response.statusCode == 204;
    } catch (e) {
      log('Error marking message as read: $e');
      return false;
    }
  }

  // Delete message
  Future<bool> deleteMessage(int messageId) async {
    try {
      final response = await _apiClient.delete('/api/messages/$messageId');

      return response.statusCode == 204;
    } catch (e) {
      log('Error deleting message: $e');
      return false;
    }
  }

  // Send message (this would typically be done via SignalR, but keeping for API consistency)
  Future<Message?> sendMessage(SendMessageRequest request) async {
    try {
      final response = await _apiClient.post(
        '/api/messages',
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Message.fromJson(data);
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      log('Error sending message: $e');
      return null;
    }
  }
}

class ApiClient {
  final String baseUrl;
  final Map<String, String> defaultHeaders;

  ApiClient({
    this.baseUrl = 'https://elearningproject.runasp.net',
    this.defaultHeaders = const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  });

  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Map<String, String> get headers {
    final headers = Map<String, String>.from(defaultHeaders);
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<http.Response> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return await http.get(uri, headers: headers);
  }

  Future<http.Response> post(String endpoint, {String? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return await http.post(uri, headers: headers, body: body);
  }

  Future<http.Response> patch(String endpoint, {String? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return await http.patch(uri, headers: headers, body: body);
  }

  Future<http.Response> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return await http.delete(uri, headers: headers);
  }
}
