class EndPoint {
  static String baseUrl = "https://elearningproject.runasp.net";
  
  // Auth endpoints
  static String register = "/api/auth/register";
  static String login = "/api/auth/login";
  static String refresh = "/api/auth/refresh";
  static String logout = "/api/auth/logout";
  static String registerAdmin = "/api/auth/register-admin";
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