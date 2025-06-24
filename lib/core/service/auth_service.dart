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

        // Check if access token is expired (after 24 minutes, leaving 6 minutes buffer)
        if (now.difference(tokenCreatedAt).inMinutes > 24) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error checking authentication status: $e');
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

      // Refresh if token is older than 20 minutes (10 minutes before expiry)
      return now.difference(tokenCreatedAt).inMinutes > 20;
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

      // Check if refresh token is still valid (7 days)
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
      
      final response = await apiConsumer.post(
        EndPoint.refresh, // Remove baseUrl as it's already set in DioConsumer
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

        print('Token refreshed successfully');
        return true;
      }

      print('Token refresh failed: Invalid response');
      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      // If refresh fails, clear tokens to force re-login
      await _clearLocalStorage();
      return false;
    }
  }

  Future<AuthResponse> login(String usernameOrEmail, String password) async {
    try {
      final response = await apiConsumer.post(
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

    // Check if response is null or empty
    if (response == null) {
      throw Exception('Server returned empty response');
    }

    return AuthResponse.fromJson(response);
  } on DioException catch (dioError) {
    // Handle Dio specific errors (400, 401, 500, etc.)
    print('Dio error: ${dioError.type}');
    print('Status code: ${dioError.response?.statusCode}');
    print('Response data: ${dioError.response?.data}');
    
    String errorMessage = 'Registration failed';
    int statusCode = dioError.response?.statusCode ?? 500;
    
    // Try to extract error message from response
    if (dioError.response?.data != null) {
      try {
        final errorData = dioError.response!.data;
        if (errorData is Map<String, dynamic>) {
          // Handle structured error response
          errorMessage = errorData['message'] ?? 
                        errorData['error'] ?? 
                        errorData['title'] ?? 
                        'Registration failed';
        } else if (errorData is String) {
          // Handle string error response
          errorMessage = errorData;
        }
      } catch (e) {
        print('Error parsing error response: $e');
      }
    } else {
      // Handle common HTTP status codes
      switch (statusCode) {
        case 400:
          errorMessage = 'Invalid registration data. Please check your input.';
          break;
        case 409:
          errorMessage = 'Username or email already exists.';
          break;
        case 422:
          errorMessage = 'Validation failed. Please check your input.';
          break;
        case 500:
          errorMessage = 'Server error. Please try again later.';
          break;
        default:
          errorMessage = 'Registration failed. Please try again.';
      }
    }
    
    // Return an AuthResponse with error details instead of throwing
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
  } catch (e) {
    print('Registration error: $e');
    
    // Return an AuthResponse with generic error
    return AuthResponse(
      statusCode: 500,
      message: 'Registration failed: ${e.toString()}',
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
          // Make the API call with both authorization header and refresh token in body
          final response = await apiConsumer.post(
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
      await _clearLocalStorage();
    } catch (e) {
      print('Error clearing authentication data: $e');
    }
  }

  // New method to check and refresh token proactively
  Future<bool> validateAndRefreshTokenIfNeeded() async {
    try {
      // First check if we have tokens
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();
      
      if (accessToken == null || refreshToken == null) {
        print('No tokens available');
        return false;
      }

      // Check if access token is still valid
      final isAuthenticated = await isUserAuthenticated();
      
      if (!isAuthenticated) {
        print('Access token expired, attempting refresh...');
        return await refreshTokenIfNeeded();
      }

      // Check if we should proactively refresh the token
      final shouldRefresh = await shouldRefreshToken();
      
      if (shouldRefresh) {
        print('Proactively refreshing token...');
        return await refreshTokenIfNeeded();
      }

      print('Token is still valid');
      return true;
    } catch (e) {
      print('Error validating and refreshing token: $e');
      return false;
    }
  }
}