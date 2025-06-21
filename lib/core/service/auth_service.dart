import 'package:e_learning_app/core/model/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:e_learning_app/core/api/api_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'package:dio/dio.dart';

class AuthService {
  final _secureStorage = const FlutterSecureStorage();
  final ApiConsumer apiConsumer;

  AuthService({required this.apiConsumer});

  Future<bool> isUserAuthenticated() async {
    try {
      final accessToken = await _secureStorage.read(key: ApiKey.accessToken);

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
      final refreshToken = await _secureStorage.read(key: ApiKey.refreshToken);
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final tokenCreatedAtString =
          await _secureStorage.read(key: 'tokenCreatedAt');
      if (tokenCreatedAtString != null) {
        final tokenCreatedAt = DateTime.parse(tokenCreatedAtString);
        final now = DateTime.now();

        // If token is less than 144 hours old (6 days), it's still valid
        if (now.difference(tokenCreatedAt).inHours < 144) {
          return true;
        }
      }

      final response = await apiConsumer.post(
        '${EndPoint.baseUrl}${EndPoint.refresh}',
        data: {
          ApiKey.refreshToken: refreshToken,
        },
      );

      final authResponse = AuthResponse.fromJson(response);

      if (authResponse.statusCode == 200 && authResponse.accessToken != null) {
        await _secureStorage.write(
            key: ApiKey.accessToken, value: authResponse.accessToken);
        await _secureStorage.write(
            key: ApiKey.refreshToken, value: authResponse.refreshToken);
        await _secureStorage.write(
            key: 'tokenCreatedAt', value: DateTime.now().toIso8601String());

        if (authResponse.user.email.isNotEmpty) {
          await _secureStorage.write(
              key: ApiKey.email, value: authResponse.user.email);
        }

        if (authResponse.user.username.isNotEmpty) {
          await _secureStorage.write(
              key: ApiKey.username, value: authResponse.user.username);
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
            key: ApiKey.accessToken, value: authResponse.accessToken);
        await _secureStorage.write(
            key: ApiKey.refreshToken, value: authResponse.refreshToken);
        await _secureStorage.write(
            key: 'tokenCreatedAt', value: DateTime.now().toIso8601String());
        await _secureStorage.write(
            key: ApiKey.userId, value: authResponse.user.userId.toString());
        await _secureStorage.write(
            key: ApiKey.username, value: authResponse.user.username);
        await _secureStorage.write(
            key: ApiKey.email, value: authResponse.user.email);
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
          ApiKey.username: username,
          ApiKey.email: email,
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
    final refreshToken = await _secureStorage.read(key: ApiKey.refreshToken);
    final accessToken = await _secureStorage.read(key: ApiKey.accessToken);

    if (refreshToken != null && accessToken != null) {
      try {
        // Make the API call with both authorization header and refresh token in body
        final response = await apiConsumer.post(
          '${EndPoint.baseUrl}${EndPoint.logout}',
          data: {
            ApiKey.refreshToken: refreshToken,
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          ),
        );

        // Clear local storage regardless of API response
        await _clearLocalStorage();

        // Handle the response based on its type
        if (response is Map<String, dynamic>) {
          return response;
        } else if (response is String) {
          // If response is a string, parse it or create a proper response
          return {
            'success': true,
            'message': 'Logged out successfully',
            'statusCode': 200,
          };
        } else {
          return {
            'success': true,
            'message': 'Logged out successfully',
            'statusCode': 200,
          };
        }
      } catch (apiError) {
        // If API call fails, still clear local storage
        print('API logout failed: $apiError');
        await _clearLocalStorage();
        
        // Return success since local cleanup is what matters most
        return {
          'success': true,
          'message': 'Logged out locally (API call failed)',
          'statusCode': 200,
        };
      }
    } else {
      // No tokens found, just clear any remaining data
      await _clearLocalStorage();
      return {
        'success': true,
        'message': 'Already logged out',
        'statusCode': 200,
      };
    }
  } catch (e) {
    print('Error during logout: $e');
    // Ensure local storage is cleared even if there's an error
    await _clearLocalStorage();
    throw Exception('Failed to logout: $e');
  }
}

Future<void> _clearLocalStorage() async {
  await _secureStorage.delete(key: ApiKey.accessToken);
  await _secureStorage.delete(key: ApiKey.refreshToken);
  await _secureStorage.delete(key: 'tokenCreatedAt');
  await _secureStorage.delete(key: ApiKey.userId);
  await _secureStorage.delete(key: ApiKey.username);
  await _secureStorage.delete(key: ApiKey.email);
}
  Future<Map<String, dynamic>> registerAdmin(int userId) async {
    try {
      final response = await apiConsumer.post(
        '${EndPoint.baseUrl}${EndPoint.registerAdmin}',
        data: {
          ApiKey.userId: userId,
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
      final userId = await _secureStorage.read(key: ApiKey.userId);
      final username = await _secureStorage.read(key: ApiKey.username);
      final email = await _secureStorage.read(key: ApiKey.email);

      if (userId == null || username == null || email == null) {
        return null;
      }

      return User(
        userId: int.parse(userId),
        username: username,
        email: email,
        isAuthenticated: true,
        roles: [
          'User'
        ], // Default role, you might want to store and retrieve actual roles
        refreshTokenExpiration: null,
      );
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: ApiKey.accessToken);
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: ApiKey.refreshToken);
    } catch (e) {
      print('Error getting refresh token: $e');
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

  Future<bool> isAdmin() async {
    return await hasRole('Admin');
  }

  Future<void> clearAuthenticationData() async {
    try {
      await _secureStorage.delete(key: ApiKey.accessToken);
      await _secureStorage.delete(key: ApiKey.refreshToken);
      await _secureStorage.delete(key: 'tokenCreatedAt');
      await _secureStorage.delete(key: ApiKey.userId);
      await _secureStorage.delete(key: ApiKey.username);
      await _secureStorage.delete(key: ApiKey.email);
    } catch (e) {
      print('Error clearing authentication data: $e');
    }
  }
}
