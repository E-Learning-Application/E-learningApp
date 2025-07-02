import 'package:e_learning_app/core/model/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'package:dio/dio.dart';

class AuthService {
  final _secureStorage = const FlutterSecureStorage();
  final DioConsumer dioConsumer;

  AuthService({required this.dioConsumer});

  // Enhanced token validation method
  Future<bool> isTokenValid() async {
    try {
      final accessToken = await _secureStorage.read(key: ApiKey.accessToken);

      if (accessToken == null || accessToken.isEmpty) {
        print('No access token found');
        return false;
      }

      final tokenCreatedAtString =
          await _secureStorage.read(key: 'tokenCreatedAt');

      if (tokenCreatedAtString == null) {
        print('No token creation time found');
        return false;
      }

      final tokenCreatedAt = DateTime.parse(tokenCreatedAtString);
      final now = DateTime.now();
      final tokenAge = now.difference(tokenCreatedAt).inMinutes;

      print('Token age: $tokenAge minutes');

      // Token expires after 30 minutes (adjust based on your backend)
      return tokenAge < 30;
    } catch (e) {
      print('Error checking token validity: $e');
      return false;
    }
  }

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

        if (now.difference(tokenCreatedAt).inMinutes > 30) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error checking authentication status: $e');
      return false;
    }
  }

  // Enhanced authentication check with automatic refresh
  Future<bool> isUserAuthenticatedWithRefresh() async {
    try {
      // First check if we have basic tokens
      final accessToken = await _secureStorage.read(key: ApiKey.accessToken);
      final refreshToken = await _secureStorage.read(key: ApiKey.refreshToken);

      if (accessToken == null || refreshToken == null) {
        print('Missing tokens');
        return false;
      }

      // Check if access token is still valid
      if (await isTokenValid()) {
        print('Access token is still valid');
        return true;
      }

      // Access token expired, try to refresh
      print('Access token expired, attempting refresh...');
      final refreshSuccess = await refreshTokenIfNeeded();

      if (refreshSuccess) {
        print('Token refreshed successfully');
        return true;
      } else {
        print('Token refresh failed');
        return false;
      }
    } catch (e) {
      print('Error in authentication check: $e');
      return false;
    }
  }

  Future<bool> shouldRefreshToken() async {
    try {
      final tokenCreatedAtString =
          await _secureStorage.read(key: 'tokenCreatedAt');

      if (tokenCreatedAtString == null) {
        return false;
      }

      final tokenCreatedAt = DateTime.parse(tokenCreatedAtString);
      final now = DateTime.now();

      // Refresh if token is older than 25 minutes (5 minutes before expiry)
      return now.difference(tokenCreatedAt).inMinutes > 25;
    } catch (e) {
      print('Error checking if token should refresh: $e');
      return false;
    }
  }

  Future<bool> refreshTokenIfNeeded() async {
    try {
      final refreshToken = await _secureStorage.read(key: ApiKey.refreshToken);
      if (refreshToken == null || refreshToken.isEmpty) {
        print('No refresh token available');
        return false;
      }

      final tokenCreatedAtString =
          await _secureStorage.read(key: 'tokenCreatedAt');
      if (tokenCreatedAtString != null) {
        final tokenCreatedAt = DateTime.parse(tokenCreatedAtString);
        final now = DateTime.now();

        // If refresh token is expired (after 7 days), return false
        if (now.difference(tokenCreatedAt).inDays >= 7) {
          print('Refresh token expired');
          await _clearLocalStorage();
          return false;
        }
      }

      print('Attempting to refresh token...');

      final response = await dioConsumer.post(
        EndPoint.refresh,
        data: {
          ApiKey.refreshToken: refreshToken,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('Refresh token response received');

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

        await _secureStorage.write(
            key: ApiKey.roles, value: authResponse.user.roles.join(','));

        print('Token refreshed successfully');
        return true;
      }

      print('Token refresh failed: Invalid response');
      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      await _clearLocalStorage();
      return false;
    }
  }

  Future<AuthResponse> login(String usernameOrEmail, String password) async {
    try {
      final response = await dioConsumer.post(
        EndPoint.login,
        data: {
          'usernameOrEmail': usernameOrEmail,
          'password': password,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
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
        await _secureStorage.write(
            key: ApiKey.roles, value: authResponse.user.roles.join(','));
      }

      return authResponse;
    } catch (e) {
      print('Login error: $e');

      String errorMessage = 'Login failed';
      int statusCode = 500;

      if (e.toString().contains('Invalid login data')) {
        errorMessage = 'Invalid login data. Please check your input.';
        statusCode = 400;
      } else if (e.toString().contains('Unauthorized')) {
        errorMessage = 'Unauthorized. Please check your credentials.';
        statusCode = 401;
      } else if (e.toString().contains('Server error')) {
        errorMessage = 'Server error. Please try again later.';
        statusCode = 500;
      } else {
        errorMessage = 'Login failed: ${e.toString()}';
      }

      return AuthResponse(
        statusCode: statusCode,
        message: errorMessage,
        accessToken: null,
        refreshToken: null,
        user: User(
          userId: 0,
          username: '',
          email: '',
          isAuthenticated: false,
          roles: [],
          refreshTokenExpiration: null,
        ),
      );
    }
  }

  Future<AuthResponse> register(String username, String email, String password,
      String confirmPassword) async {
    try {
      final response = await dioConsumer.post(
        EndPoint.register,
        data: {
          ApiKey.username: username,
          ApiKey.email: email,
          'password': password,
          'confirmPassword': confirmPassword,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response == null) {
        return AuthResponse(
          statusCode: 500,
          message: 'Server returned empty response',
          user: User(
              userId: 0,
              username: '',
              email: '',
              isAuthenticated: false,
              roles: []),
        );
      }

      return AuthResponse.fromJson(response);
    } catch (e) {
      print('Registration error: $e');

      String errorMessage = 'Registration failed';
      int statusCode = 500;

      if (e.toString().contains('Invalid registration data')) {
        errorMessage = 'Invalid registration data. Please check your input.';
        statusCode = 400;
      } else if (e.toString().contains('Username or email already exists')) {
        errorMessage = 'Username or email already exists.';
        statusCode = 409;
      } else if (e.toString().contains('Server error')) {
        errorMessage = 'Server error. Please try again later.';
        statusCode = 500;
      } else {
        errorMessage = 'Registration failed: ${e.toString()}';
      }

      return AuthResponse(
        statusCode: statusCode,
        message: errorMessage,
        accessToken: null,
        refreshToken: null,
        user: User(
          userId: 0,
          username: '',
          email: '',
          isAuthenticated: false,
          roles: [],
          refreshTokenExpiration: null,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      final refreshToken = await _secureStorage.read(key: ApiKey.refreshToken);
      final accessToken = await _secureStorage.read(key: ApiKey.accessToken);

      if (refreshToken != null && accessToken != null) {
        try {
          final response = await dioConsumer.post(
            EndPoint.logout,
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

          await _clearLocalStorage();

          if (response is Map<String, dynamic>) {
            return response;
          } else if (response is String) {
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
          print('API logout failed: $apiError');
          await _clearLocalStorage();

          return {
            'success': true,
            'message': 'Logged out locally (API call failed)',
            'statusCode': 200,
          };
        }
      } else {
        await _clearLocalStorage();
        return {
          'success': true,
          'message': 'Already logged out',
          'statusCode': 200,
        };
      }
    } catch (e) {
      print('Error during logout: $e');
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
    await _secureStorage.delete(key: ApiKey.roles);
  }

  Future<Map<String, dynamic>> registerAdmin(int userId) async {
    try {
      final response = await dioConsumer.post(
        EndPoint.registerAdmin,
        data: {
          ApiKey.userId: userId,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
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
      final rolesString = await _secureStorage.read(key: ApiKey.roles);

      if (userId == null || username == null || email == null) {
        return null;
      }

      List<String> roles = [];
      if (rolesString != null && rolesString.isNotEmpty) {
        roles = rolesString.split(',').map((role) => role.trim()).toList();
      } else {
        roles = ['User'];
      }

      return User(
        userId: int.parse(userId),
        username: username,
        email: email,
        isAuthenticated: true,
        roles: roles,
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

      return user.roles
          .any((userRole) => userRole.toLowerCase() == role.toLowerCase());
    } catch (e) {
      print('Error checking role: $e');
      return false;
    }
  }

  Future<bool> isAdmin() async {
    return await hasRole('admin');
  }

  Future<void> clearAuthenticationData() async {
    try {
      await _clearLocalStorage();
    } catch (e) {
      print('Error clearing authentication data: $e');
    }
  }

  // Updated validateAndRefreshTokenIfNeeded method
  Future<bool> validateAndRefreshTokenIfNeeded() async {
    try {
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();

      if (accessToken == null || refreshToken == null) {
        print('No tokens available for validation');
        return false;
      }

      // Check if refresh token itself is expired
      final tokenCreatedAtString =
          await _secureStorage.read(key: 'tokenCreatedAt');

      if (tokenCreatedAtString != null) {
        final tokenCreatedAt = DateTime.parse(tokenCreatedAtString);
        final now = DateTime.now();

        // If refresh token is expired (after 7 days), clear everything
        if (now.difference(tokenCreatedAt).inDays >= 7) {
          print('Refresh token expired, clearing all tokens');
          await _clearLocalStorage();
          return false;
        }
      }

      // Check if access token is valid
      if (await isTokenValid()) {
        print('Access token is valid, no refresh needed');
        return true;
      }

      // Access token expired, attempt refresh
      print('Access token expired, attempting refresh...');
      final refreshSuccess = await refreshTokenIfNeeded();

      if (refreshSuccess) {
        print('Token refreshed successfully');
        return true;
      } else {
        print('Token refresh failed');
        await _clearLocalStorage();
        return false;
      }
    } catch (e) {
      print('Error validating and refreshing token: $e');
      await _clearLocalStorage();
      return false;
    }
  }

  // Method to handle app resume scenarios
  Future<bool> handleAppResume() async {
    try {
      print('Handling app resume - checking token status');

      // Use the enhanced authentication check
      return await isUserAuthenticatedWithRefresh();
    } catch (e) {
      print('Error handling app resume: $e');
      return false;
    }
  }

  // Method to check if tokens exist
  Future<bool> hasTokens() async {
    try {
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();
      return accessToken != null && refreshToken != null;
    } catch (e) {
      print('Error checking if tokens exist: $e');
      return false;
    }
  }

  // Method to get token creation time
  Future<DateTime?> getTokenCreationTime() async {
    try {
      final tokenCreatedAtString =
          await _secureStorage.read(key: 'tokenCreatedAt');
      if (tokenCreatedAtString != null) {
        return DateTime.parse(tokenCreatedAtString);
      }
      return null;
    } catch (e) {
      print('Error getting token creation time: $e');
      return null;
    }
  }

  // Method to get time until token expires
  Future<Duration?> getTimeUntilTokenExpires() async {
    try {
      final tokenCreationTime = await getTokenCreationTime();
      if (tokenCreationTime != null) {
        final now = DateTime.now();
        final tokenAge = now.difference(tokenCreationTime);
        const tokenLifetime =
            Duration(minutes: 30); // Adjust based on your backend

        if (tokenAge < tokenLifetime) {
          return tokenLifetime - tokenAge;
        }
      }
      return null;
    } catch (e) {
      print('Error calculating time until token expires: $e');
      return null;
    }
  }

  // Method to force token refresh
  Future<bool> forceTokenRefresh() async {
    try {
      print('Forcing token refresh...');
      return await refreshTokenIfNeeded();
    } catch (e) {
      print('Error forcing token refresh: $e');
      return false;
    }
  }
}
