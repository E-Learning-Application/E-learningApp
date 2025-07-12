import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:e_learning_app/core/model/message_model.dart';

class CacheService {
  static const String _chatListKey = 'chat_list_cache';
  static const String _chatListTimestampKey = 'chat_list_timestamp';
  static const String _unreadCountKey = 'unread_count_cache';
  static const Duration _cacheExpiry =
      Duration(minutes: 5); // Cache for 5 minutes

  static Future<void> cacheChatList(
      List<ChatSummary> chats, int totalUnreadCount) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert chats to JSON
      final chatsJson = chats.map((chat) => chat.toJson()).toList();

      // Store chats and unread count
      await prefs.setString(_chatListKey, jsonEncode(chatsJson));
      await prefs.setInt(_unreadCountKey, totalUnreadCount);
      await prefs.setInt(
          _chatListTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error caching chat list: $e');
    }
  }

  static Future<Map<String, dynamic>?> getCachedChatList() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if cache exists and is not expired
      final timestamp = prefs.getInt(_chatListTimestampKey);
      if (timestamp == null) return null;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      if (now.difference(cacheTime) > _cacheExpiry) {
        // Cache expired, remove it
        await clearChatListCache();
        return null;
      }

      // Get cached data
      final chatsJsonString = prefs.getString(_chatListKey);
      final unreadCount = prefs.getInt(_unreadCountKey);

      if (chatsJsonString == null || unreadCount == null) return null;

      final chatsJson = jsonDecode(chatsJsonString) as List<dynamic>;
      final chats =
          chatsJson.map((json) => ChatSummary.fromJson(json)).toList();

      return {
        'chats': chats,
        'totalUnreadCount': unreadCount,
      };
    } catch (e) {
      print('Error getting cached chat list: $e');
      return null;
    }
  }

  static Future<void> clearChatListCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatListKey);
      await prefs.remove(_chatListTimestampKey);
      await prefs.remove(_unreadCountKey);
    } catch (e) {
      print('Error clearing chat list cache: $e');
    }
  }

  static Future<bool> isChatListCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_chatListTimestampKey);
      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      return now.difference(cacheTime) <= _cacheExpiry;
    } catch (e) {
      return false;
    }
  }

  static Future<void> updateUnreadCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, count);
    } catch (e) {
      print('Error updating unread count cache: $e');
    }
  }

  static Future<int?> getCachedUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_unreadCountKey);
    } catch (e) {
      print('Error getting cached unread count: $e');
      return null;
    }
  }
}
