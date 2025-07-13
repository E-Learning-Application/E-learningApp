import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';

class TimeFormatter {
  static bool _initialized = false;
  static late tz.Location _egyptLocation;

  static void initialize() {
    if (!_initialized) {
      tz.initializeTimeZones();
      _egyptLocation = tz.getLocation('Africa/Cairo');
      _initialized = true;
    }
  }

  // Convert UTC time to Egypt time
  static DateTime toEgyptTime(DateTime utcTime) {
    initialize();

    // If the time is already in UTC, convert it to Egypt time
    if (utcTime.isUtc) {
      return tz.TZDateTime.from(utcTime, _egyptLocation);
    } else {
      // If it's local time, assume it's already in Egypt time
      // or convert to UTC first if needed
      return utcTime;
    }
  }

  // Format time for chat list (relative format)
  static String formatChatTime(DateTime dateTime) {
    final egyptTime = toEgyptTime(dateTime);
    final now = DateTime.now(); // Use local time for comparison
    final difference = now.difference(egyptTime);

    // Debug logging
    print('=== Time Debug ===');
    print('Original time: $dateTime');
    print('Egypt time: $egyptTime');
    print('Current time: $now');
    print('Difference: ${difference.inMinutes} minutes');
    print('==================');

    if (difference.isNegative) {
      return 'now';
    }

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return '1d ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d').format(egyptTime);
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  // Format time for message bubbles
  static String formatMessageTime(DateTime dateTime) {
    final egyptTime = toEgyptTime(dateTime);
    final now = DateTime.now(); // Use local time for comparison
    final difference = now.difference(egyptTime);

    // Debug logging
    print('=== Message Time Debug ===');
    print('Original time: $dateTime');
    print('Egypt time: $egyptTime');
    print('Current time: $now');
    print('Difference: ${difference.inMinutes} minutes');
    print('========================');

    if (difference.isNegative) {
      return 'Just now';
    }

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat('MMM d').format(egyptTime);
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Show actual time (12-hour format)
  static String formatActualTime(DateTime dateTime) {
    final egyptTime = toEgyptTime(dateTime);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(egyptTime.year, egyptTime.month, egyptTime.day);

    if (messageDate.isAtSameMomentAs(today)) {
      return DateFormat('h:mm a').format(egyptTime);
    } else if (messageDate
        .isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      return 'Yesterday ${DateFormat('h:mm a').format(egyptTime)}';
    } else if (now.difference(messageDate).inDays < 7) {
      return DateFormat('EEEE h:mm a').format(egyptTime);
    } else {
      return DateFormat('MMM d, h:mm a').format(egyptTime);
    }
  }

  // Simple format for debugging - shows exact time
  static String formatDebugTime(DateTime dateTime) {
    final egyptTime = toEgyptTime(dateTime);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(egyptTime);
  }
}

// Updated MessagesScreen methods
class MessagesScreenUpdated {
  String _formatTime(DateTime dateTime) {
    return TimeFormatter.formatChatTime(dateTime);
  }
}

// Updated ChatScreen methods
class ChatScreenUpdated {
  String _formatMessageTime(DateTime timestamp) {
    return TimeFormatter.formatMessageTime(timestamp);
  }
}

// UPDATED MessagesScreen - Replace your existing _formatTime method
String _formatTime(DateTime dateTime) {
  return TimeFormatter.formatChatTime(dateTime);
}

// UPDATED ChatScreen - Replace your existing _formatMessageTime method
String _formatMessageTime(DateTime timestamp) {
  return TimeFormatter.formatMessageTime(timestamp);
}

// Initialize TimeFormatter in your main.dart or app initialization
void initializeApp() {
  TimeFormatter.initialize();
}
