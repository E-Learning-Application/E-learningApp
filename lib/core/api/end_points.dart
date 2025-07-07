class EndPoint {
  static String baseUrl = "https://elearningproject.runasp.net";

  // Auth endpoints
  static String register = "/api/auth/register";
  static String login = "/api/auth/login";
  static String refresh = "/api/auth/refresh";
  static String logout = "/api/auth/logout";
  static String registerAdmin = "/api/auth/register-admin";

  // Language endpoints
  static const String getAllLanguages = '/api/language/languages';
  static const String addLanguages = '/api/language/add-languages';
  static const String updateLanguages = '/api/language/update-languages';
  static const String removeLanguages = '/api/language/remove-languages';

  // Interest endpoints
  static const String getAllInterests = '/api/interests';
  static const String addInterest = '/api/interests';
  static const String addUserInterest = '/api/interests/user-interests';
  static const String getUserInterests = '/api/interests/user-interests';
  static const String removeUserInterest =
      '/api/interests/user-interests'; // DELETE user interest

  // Language Preference endpoints
  static const String getUserLanguagePreferences =
      '/api/LanguagePreference/user-language-preferences';
  static const String updateUserLanguagePreferences =
      '/api/LanguagePreference/update-user-language-preferences';

  // User endpoints
  static const String user = "/api/user";

  // Matching endpoints
  static const String findMatch = '/api/matching/find-match';
  static const String getMatches = '/api/matching';
  static const String endMatch = '/api/matching/end';

  // Message endpoints
  static const String getAllMessages = '/api/messages';
  static const String getChatList = '/api/messages/list';
  static const String getChatWith = '/api/messages/chat';
  static const String getUnreadCount = '/api/messages/unread/count';
  static const String getLastMessage = '/api/messages/last';
  static const String sendMessage = '/api/messages';
  static const String getMessagesWithPagination = '/api/messages/paginated';
  static const String searchMessages = '/api/messages/search';
  static const String markAllMessagesAsRead = '/api/messages/read/all';

  static const String getMessageThread = '/api/messages/thread'; // + messageId
  static const String getMessageById = '/api/messages'; // + messageId
  static const String markMessageAsRead = '/api/messages/read'; // + messageId
  static const String deleteMessage = '/api/messages'; // + messageId
}

class ApiKey {
  static String status = "statusCode";
  static String message = "message";
  static String data = "data";
  static String errorMessage = "ErrorMessage";
  static String userId = "userId";
  static String username = "username";
  static String email = "email";
  static String isAuthenticated = "isAuthenticated";
  static String roles = "roles";
  static String accessToken = "accessToken";
  static String refreshToken = "refreshToken";
  static String refreshTokenExpiration = "refreshTokenExpiration";
}
