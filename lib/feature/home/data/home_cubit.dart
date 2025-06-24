import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/feature/home/data/home_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/core/model/user_model.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;

  AuthCubit({required AuthService authService})
      : _authService = authService,
        super(const AuthInitial());

  Future<void> checkAuthStatus() async {
    try {
      emit(const AuthLoading());

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
        emit(AuthAuthenticated(user: user, accessToken: accessToken));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: 'Failed to check authentication status: $e'));
    }
  }

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

  Future<void> validateAndRefreshToken() async {
    try {
      final isAuthenticated = await _authService.isUserAuthenticated();

      if (!isAuthenticated) {
        final refreshSuccess = await _authService.refreshTokenIfNeeded();
        
        if (!refreshSuccess) {
          emit(const AuthTokenExpired());
          return;
        }

        final user = await _authService.getCurrentUser();
        final accessToken = await _authService.getAccessToken();

        if (user != null && accessToken != null) {
          emit(AuthAuthenticated(user: user, accessToken: accessToken));
        } else {
          emit(const AuthTokenExpired());
        }
      } else {
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

  void setAuthenticated(User user, String accessToken) {
    emit(AuthAuthenticated(user: user, accessToken: accessToken));
  }

  User? get currentUser {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      return currentState.user;
    }
    return null;
  }

  bool get isAuthenticated {
    return state is AuthAuthenticated;
  }

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
}