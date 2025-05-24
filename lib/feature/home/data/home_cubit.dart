// auth_cubit.dart
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/feature/home/data/home_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/core/model/user_model.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;

  AuthCubit({required AuthService authService})
      : _authService = authService,
        super(const AuthInitial());

  /// Check initial authentication status when app starts
  Future<void> checkAuthStatus() async {
    try {
      emit(const AuthLoading());

      // Check if user is authenticated
      final isAuthenticated = await _authService.isUserAuthenticated();

      if (!isAuthenticated) {
        // Try to refresh token if available
        final refreshSuccess = await _authService.refreshTokenIfNeeded();
        
        if (!refreshSuccess) {
          emit(const AuthUnauthenticated());
          return;
        }
      }

      // Get current user and access token
      final user = await _authService.getCurrentUser();
      final accessToken = await _authService.getAccessToken();

      if (user != null && accessToken != null) {
        emit(AuthAuthenticated(user: user, accessToken: accessToken));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: 'Failed to check authentication status: $e'));
    }
  }

  /// Refresh access token using refresh token
  Future<void> refreshToken() async {
    try {
      emit(const AuthLoading());

      final refreshSuccess = await _authService.refreshTokenIfNeeded();

      if (refreshSuccess) {
        final user = await _authService.getCurrentUser();
        final accessToken = await _authService.getAccessToken();

        if (user != null && accessToken != null) {
          emit(AuthAuthenticated(user: user, accessToken: accessToken));
        } else {
          emit(const AuthTokenExpired());
        }
      } else {
        emit(const AuthTokenExpired());
      }
    } catch (e) {
      emit(const AuthTokenExpired(message: 'Session expired. Please login again.'));
    }
  }

  /// Validate current token and refresh if needed
  Future<void> validateAndRefreshToken() async {
    try {
      // First check if user is currently authenticated
      final isAuthenticated = await _authService.isUserAuthenticated();

      if (!isAuthenticated) {
        // Try to refresh token
        final refreshSuccess = await _authService.refreshTokenIfNeeded();
        
        if (!refreshSuccess) {
          emit(const AuthTokenExpired());
          return;
        }

        // After successful refresh, get updated user info
        final user = await _authService.getCurrentUser();
        final accessToken = await _authService.getAccessToken();

        if (user != null && accessToken != null) {
          emit(AuthAuthenticated(user: user, accessToken: accessToken));
        } else {
          emit(const AuthTokenExpired());
        }
      } else {
        // Token is still valid, just emit current state
        final user = await _authService.getCurrentUser();
        final accessToken = await _authService.getAccessToken();

        if (user != null && accessToken != null) {
          emit(AuthAuthenticated(user: user, accessToken: accessToken));
        } else {
          emit(const AuthUnauthenticated());
        }
      }
    } catch (e) {
      emit(const AuthTokenExpired(message: 'Session validation failed. Please login again.'));
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      emit(const AuthLoading());
      
      await _authService.logout();
      emit(const AuthUnauthenticated());
    } catch (e) {
      // Even if logout fails, clear local data and move to unauthenticated state
      await _authService.clearAuthenticationData();
      emit(const AuthUnauthenticated());
    }
  }

  /// Clear authentication data without API call
  Future<void> clearAuth() async {
    try {
      await _authService.clearAuthenticationData();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }

  /// Set authenticated state after successful login (to be called from login flow)
  void setAuthenticated(User user, String accessToken) {
    emit(AuthAuthenticated(user: user, accessToken: accessToken));
  }

  /// Get current user if authenticated
  User? get currentUser {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      return currentState.user;
    }
    return null;
  }

  /// Check if user is currently authenticated
  bool get isAuthenticated {
    return state is AuthAuthenticated;
  }

  /// Check if current user has specific role
  Future<bool> hasRole(String role) async {
    try {
      return await _authService.hasRole(role);
    } catch (e) {
      return false;
    }
  }

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    try {
      return await _authService.isAdmin();
    } catch (e) {
      return false;
    }
  }
}