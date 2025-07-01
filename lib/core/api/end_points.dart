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

  // Language Preference endpoints
  static const String getUserLanguagePreferences =
      '/api/LanguagePreference/user-language-preferences';
  static const String updateUserLanguagePreferences =
      '/api/LanguagePreference/update-user-language-preferences';
  // User endpoints
  static const String user = "/api/user";
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
