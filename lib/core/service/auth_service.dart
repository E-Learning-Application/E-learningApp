import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:e_learning_app/core/api/api_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';

class AuthService {
  final _secureStorage = const FlutterSecureStorage();
  final ApiConsumer apiConsumer;

  AuthService({required this.apiConsumer});

  Future<bool> isUserAuthenticated() async {
    try {
      final accessToken = await _secureStorage.read(key: 'accessToken');

      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }

      final tokenCreatedAtString =
          await _secureStorage.read(key: 'tokenCreatedAt');
      if (tokenCreatedAtString != null) {
        final tokenCreatedAt = DateTime.parse(tokenCreatedAtString);
        final now = DateTime.now();

        if (now.difference(tokenCreatedAt).inDays > 7) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error checking authentication status: $e');
      return false;
    }
  }

  Future<bool> refreshTokenIfNeeded() async {
    try {
      final refreshToken = await _secureStorage.read(key: 'refreshToken');
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final tokenCreatedAtString =
          await _secureStorage.read(key: 'tokenCreatedAt');
      if (tokenCreatedAtString != null) {
        final tokenCreatedAt = DateTime.parse(tokenCreatedAtString);
        final now = DateTime.now();

        if (now.difference(tokenCreatedAt).inHours < 144) {
          return true;
        }
      }

      final response = await apiConsumer.post(
        '${EndPoint.baseUrl}${EndPoint.refresh}',
        data: {
          'refreshToken': refreshToken,
        },
      );

      final authResponse = AuthResponse.fromJson(response);

      if (authResponse.statusCode == 200 && authResponse.accessToken != null) {
        await _secureStorage.write(
            key: 'accessToken', value: authResponse.accessToken);
        await _secureStorage.write(
            key: 'refreshToken', value: authResponse.refreshToken);
        await _secureStorage.write(
            key: 'tokenCreatedAt', value: DateTime.now().toIso8601String());

        if (authResponse.user.email.isNotEmpty) {
          await _secureStorage.write(
              key: 'email', value: authResponse.user.email);
        }

        if (authResponse.user.username.isNotEmpty) {
          await _secureStorage.write(
              key: 'username', value: authResponse.user.username);
        }

        return true;
      }

      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  Future<AuthResponse> login(String usernameOrEmail, String password) async {
    try {
      final response = await apiConsumer.post(
        '${EndPoint.baseUrl}${EndPoint.login}',
        data: {
          'usernameOrEmail': usernameOrEmail,
          'password': password,
        },
      );

      final authResponse = AuthResponse.fromJson(response);

      if (authResponse.statusCode == 200 && authResponse.accessToken != null) {
        await _secureStorage.write(
            key: 'accessToken', value: authResponse.accessToken);
        await _secureStorage.write(
            key: 'refreshToken', value: authResponse.refreshToken);
        await _secureStorage.write(
            key: 'tokenCreatedAt', value: DateTime.now().toIso8601String());
        await _secureStorage.write(
            key: 'userId', value: authResponse.user.userId.toString());
        await _secureStorage.write(
            key: 'username', value: authResponse.user.username);
        await _secureStorage.write(
            key: 'email', value: authResponse.user.email);
      }

      return authResponse;
    } catch (e) {
      print('Login error: $e');
      throw Exception('Failed to login: $e');
    }
  }

  Future<AuthResponse> register(String username, String email, String password,
      String confirmPassword) async {
    try {
      final response = await apiConsumer.post(
        '${EndPoint.baseUrl}${EndPoint.register}',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword,
        },
      );

      return AuthResponse.fromJson(response);
    } catch (e) {
      print('Registration error: $e');
      throw Exception('Failed to register: $e');
    }
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      final refreshToken = await _secureStorage.read(key: 'refreshToken');

      if (refreshToken != null) {
        final response = await apiConsumer.post(
          '${EndPoint.baseUrl}${EndPoint.logout}',
          data: {
            'refreshToken': refreshToken,
          },
        );
        await _secureStorage.delete(key: 'accessToken');
        await _secureStorage.delete(key: 'refreshToken');
        await _secureStorage.delete(key: 'tokenCreatedAt');
        await _secureStorage.delete(key: 'userId');
        await _secureStorage.delete(key: 'username');
        await _secureStorage.delete(key: 'email');

        return response;
      } else {
        throw Exception('No refresh token found');
      }
    } catch (e) {
      print('Error during logout: $e');
      throw Exception('Failed to logout: $e');
    }
  }

  Future<Map<String, dynamic>> registerAdmin(int userId) async {
    try {
      final response = await apiConsumer.post(
        '${EndPoint.baseUrl}${EndPoint.registerAdmin}',
        data: {
          'UserId': userId,
        },
      );

      return response;
    } catch (e) {
      print('Register admin error: $e');
      throw Exception('Failed to register admin: $e');
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final userId = await _secureStorage.read(key: 'userId');
      final username = await _secureStorage.read(key: 'username');
      final email = await _secureStorage.read(key: 'email');

      if (userId == null || username == null || email == null) {
        return null;
      }

      return User(
        userId: int.parse(userId),
        username: username,
        email: email,
        isAuthenticated: true,
        roles: ['User'],
        refreshTokenExpiration: null,
      );
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: 'accessToken');
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }

  Future<bool> hasRole(String role) async {
    try {
      final user = await getCurrentUser();
      if (user == null) {
        return false;
      }

      return user.roles.contains(role);
    } catch (e) {
      print('Error checking role: $e');
      return false;
    }
  }
}

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
      userId: json['userId'],
      username: json['username'],
      email: json['email'],
      isAuthenticated: json['isAuthenticated'],
      roles: List<String>.from(json['roles']),
      refreshTokenExpiration: json['refreshTokenExpiration'] != null &&
              json['refreshTokenExpiration'] != "0001-01-01T00:00:00"
          ? DateTime.parse(json['refreshTokenExpiration'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
      'isAuthenticated': isAuthenticated,
      'roles': roles,
      'refreshTokenExpiration': refreshTokenExpiration?.toIso8601String(),
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
    final userData = json['data'];
    return AuthResponse(
      user: User.fromJson(userData),
      accessToken: userData['accessToken'],
      refreshToken: userData['refreshToken'],
      statusCode: json['statusCode'],
      message: json['message'] ?? '',
    );
  }
}

class LoginRequest {
  final String usernameOrEmail;
  final String password;

  LoginRequest({
    required this.usernameOrEmail,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'usernameOrEmail': usernameOrEmail,
      'password': password,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

class RegisterRequest {
  final String username;
  final String email;
  final String password;
  final String confirmPassword;

  RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

class RefreshTokenRequest {
  final String refreshToken;

  RefreshTokenRequest({
    required this.refreshToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'refreshToken': refreshToken,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}
