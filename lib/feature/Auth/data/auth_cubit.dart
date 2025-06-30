import 'package:e_learning_app/core/model/user_model.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/feature/Auth/data/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;

  AuthCubit({required AuthService authService})
      : _authService = authService,
        super(const AuthInitial());

  // Authentication Status Management
  Future<void> checkAuthStatus() async {
    try {
      // Don't emit loading if already authenticated
      if (state is! AuthAuthenticated && state is! LoginSuccess) {
        emit(const AuthLoading());
      }

      final isAuthenticated = await _authService.isUserAuthenticated();

      if (!isAuthenticated) {
        final refreshSuccess = await _authService.refreshTokenIfNeeded();

        if (!refreshSuccess) {
          emit(const AuthUnauthenticated());
          return;
        }
      }

      final user = await _authService.getCurrentUser();
      final accessToken = await _authService.getAccessToken();

      if (user != null && accessToken != null) {
        // Only emit if the state is actually different
        final currentState = state;
        if (currentState is! AuthAuthenticated ||
            currentState.user != user ||
            currentState.accessToken != accessToken) {
          emit(AuthAuthenticated(user: user, accessToken: accessToken));
        }
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: 'Failed to check authentication status: $e'));
    }
  }

  Future<void> validateAndRefreshToken() async {
    try {
      // Don't show loading for background validation
      final isValid = await _authService.validateAndRefreshTokenIfNeeded();

      if (isValid) {
        final user = await _authService.getCurrentUser();
        final accessToken = await _authService.getAccessToken();

        if (user != null && accessToken != null) {
          // Only emit if the state is actually different
          final currentState = state;
          if (currentState is! AuthAuthenticated ||
              currentState.user != user ||
              currentState.accessToken != accessToken) {
            emit(AuthAuthenticated(user: user, accessToken: accessToken));
          }
        } else {
          emit(const AuthTokenExpired(message: 'Session validation failed'));
        }
      } else {
        emit(const AuthTokenExpired(
            message: 'Session expired. Please login again.'));
      }
    } catch (e) {
      emit(const AuthTokenExpired(
          message: 'Session validation failed. Please login again.'));
    }
  }

  Future<void> refreshToken() async {
    try {
      // Don't emit loading if already authenticated
      if (state is! AuthAuthenticated) {
        emit(const AuthLoading());
      }

      final refreshSuccess = await _authService.refreshTokenIfNeeded();

      if (refreshSuccess) {
        final user = await _authService.getCurrentUser();
        final accessToken = await _authService.getAccessToken();

        if (user != null && accessToken != null) {
          emit(AuthAuthenticated(user: user, accessToken: accessToken));
        } else {
          emit(const AuthTokenExpired(message: 'Failed to refresh token'));
        }
      } else {
        emit(const AuthTokenExpired(message: 'Token refresh failed'));
      }
    } catch (e) {
      emit(const AuthTokenExpired(
          message: 'Session expired. Please login again.'));
    }
  }

  // Login functionality
  Future<void> login(String usernameOrEmail, String password) async {
    emit(const LoginLoading());

    try {
      final response = await _authService.login(usernameOrEmail, password);

      if (response.statusCode == 200 && response.accessToken != null) {
        emit(LoginSuccess(
          user: response.user,
          accessToken: response.accessToken!,
        ));
      } else {
        emit(LoginFailure(message: response.message));
      }
    } catch (e) {
      emit(LoginFailure(message: 'Login failed: ${e.toString()}'));
    }
  }

  // Registration functionality with validation
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    emit(const RegisterLoading());

    try {
      // Client-side validation
      if (password != confirmPassword) {
        emit(const RegisterFailure(message: 'Passwords do not match'));
        return;
      }

      if (!isPasswordStrong(password)) {
        emit(const RegisterFailure(
          message:
              'Password is not strong enough. It should contain at least 8 characters, including uppercase, lowercase, numbers, and special characters.',
        ));
        return;
      }

      if (!isEmailValid(email)) {
        emit(const RegisterFailure(
          message: 'Please enter a valid email address',
        ));
        return;
      }

      final response = await _authService.register(
        username,
        email,
        password,
        confirmPassword,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        emit(RegisterSuccess(
          message: response.message,
          user: response.user,
        ));
      } else {
        emit(RegisterFailure(message: response.message));
      }
    } catch (e) {
      emit(RegisterFailure(message: 'Registration failed: ${e.toString()}'));
    }
  }

  // Logout functionality
  Future<void> logout() async {
    emit(const AuthLoading());

    try {
      final result = await _authService.logout();

      if (result['success'] == true) {
        emit(const AuthUnauthenticated());
      } else {
        emit(AuthError(message: result['message'] ?? 'Logout failed'));
      }
    } catch (e) {
      // Even if logout fails on server side, clear local state
      emit(const AuthUnauthenticated());
    }
  }

  // Admin registration
  Future<void> registerAdmin(int userId) async {
    emit(const AuthLoading());

    try {
      final result = await _authService.registerAdmin(userId);

      // Refresh user data after admin registration
      await checkAuthStatus();
    } catch (e) {
      emit(AuthError(message: 'Failed to register admin: ${e.toString()}'));
    }
  }

  // Clear authentication data
  Future<void> clearAuthData() async {
    try {
      await _authService.clearAuthenticationData();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: 'Failed to clear auth data: ${e.toString()}'));
    }
  }

  void setAuthenticated(User user, String accessToken) {
    // Only emit if the state is actually different
    final currentState = state;
    if (currentState is! AuthAuthenticated ||
        currentState.user != user ||
        currentState.accessToken != accessToken) {
      emit(AuthAuthenticated(user: user, accessToken: accessToken));
    }
  }

  void setUnauthenticated() {
    if (state is! AuthUnauthenticated) {
      emit(const AuthUnauthenticated());
    }
  }

  // Getters for convenience
  User? get currentUser {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      return currentState.user;
    } else if (currentState is LoginSuccess) {
      return currentState.user;
    }
    return null;
  }

  String? get accessToken {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      return currentState.accessToken;
    } else if (currentState is LoginSuccess) {
      return currentState.accessToken;
    }
    return null;
  }

  bool get isAuthenticated =>
      state is AuthAuthenticated || state is LoginSuccess;

  bool get isLoading =>
      state is AuthLoading || state is LoginLoading || state is RegisterLoading;

  bool get hasError => state is AuthError;

  String? get errorMessage {
    final currentState = state;
    if (currentState is AuthError) {
      return currentState.message;
    }
    return null;
  }

  // Role checking methods
  Future<bool> hasRole(String role) async {
    try {
      return await _authService.hasRole(role);
    } catch (e) {
      return false;
    }
  }

  Future<bool> isAdmin() async {
    try {
      return await _authService.isAdmin();
    } catch (e) {
      return false;
    }
  }

  // Token utilities
  Future<String?> getStoredAccessToken() async {
    return await _authService.getAccessToken();
  }

  Future<String?> getStoredRefreshToken() async {
    return await _authService.getRefreshToken();
  }

  // Reset to initial state (useful for forms)
  void reset() {
    emit(const AuthInitial());
  }

  // Reset to unauthenticated state
  void resetToUnauthenticated() {
    emit(const AuthUnauthenticated());
  }

  // Validation utilities
  bool isPasswordStrong(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  bool isEmailValid(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
