
import 'package:e_learning_app/core/api/end_points.dart';

class User {
  final int userId;
  final String username;
  final String email;
  final bool isAuthenticated;
  final List<String> roles;
  final DateTime? refreshTokenExpiration;

  User({
    required this.userId,
    required this.username,
    required this.email,
    required this.isAuthenticated,
    required this.roles,
    this.refreshTokenExpiration,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json[ApiKey.userId],
      username: json[ApiKey.username],
      email: json[ApiKey.email],
      isAuthenticated: json[ApiKey.isAuthenticated],
      roles: List<String>.from(json[ApiKey.roles] ?? ['User']),
      refreshTokenExpiration: json[ApiKey.refreshTokenExpiration] != null &&
              json[ApiKey.refreshTokenExpiration] != "0001-01-01T00:00:00"
          ? DateTime.parse(json[ApiKey.refreshTokenExpiration])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ApiKey.userId: userId,
      ApiKey.username: username,
      ApiKey.email: email,
      ApiKey.isAuthenticated: isAuthenticated,
      ApiKey.roles: roles,
      ApiKey.refreshTokenExpiration: refreshTokenExpiration?.toIso8601String(),
    };
  }
}

class AuthResponse {
  final User user;
  final String? accessToken;
  final String? refreshToken;
  final int statusCode;
  final String message;

  AuthResponse({
    required this.user,
    this.accessToken,
    this.refreshToken,
    required this.statusCode,
    required this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final userData = json[ApiKey.data];
    return AuthResponse(
      user: User.fromJson(userData),
      accessToken: userData[ApiKey.accessToken],
      refreshToken: userData[ApiKey.refreshToken],
      statusCode: json[ApiKey.status],
      message: json[ApiKey.message] ?? '',
    );
  }
}
