import 'package:e_learning_app/feature/language/data/language_state.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Import your actual language service
import 'package:e_learning_app/core/service/language_service.dart';

class LanguageCubit extends Cubit<LanguageState> {
  final LanguageService languageService;
  final AuthService authService;

  LanguageCubit({
    required this.languageService,
    required this.authService,
  }) : super(LanguageInitial());

  /// Get all available languages with authentication
  Future<void> getAllLanguages() async {
    try {
      emit(LanguageLoading());

      // Validate and refresh token if needed
      final isTokenValid = await authService.validateAndRefreshTokenIfNeeded();

      if (!isTokenValid) {
        emit(LanguageError(
            message: 'Authentication failed. Please login again.'));
        return;
      }

      // Get the access token
      final accessToken = await authService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        emit(LanguageError(
            message: 'No access token available. Please login again.'));
        return;
      }

      // Call the language service with the access token
      final response =
          await languageService.getAllLanguages(accessToken: accessToken);

      if (response.statusCode == 200) {
        emit(LanguageSuccess(languages: response.data));
      } else {
        // Handle specific authentication errors
        if (response.statusCode == 401) {
          emit(LanguageError(message: 'Session expired. Please login again.'));
        } else {
          emit(LanguageError(message: response.message));
        }
      }
    } catch (e) {
      emit(LanguageError(message: _handleError(e)));
    }
  }

  /// Get user language preferences with authentication
  Future<void> getUserLanguagePreferences() async {
    try {
      emit(LanguageLoading());

      // Validate and refresh token if needed
      final isTokenValid = await authService.validateAndRefreshTokenIfNeeded();

      if (!isTokenValid) {
        emit(LanguageError(
            message: 'Authentication failed. Please login again.'));
        return;
      }

      // Get the access token
      final accessToken = await authService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        emit(LanguageError(
            message: 'No access token available. Please login again.'));
        return;
      }

      // Get current user
      final currentUser = await authService.getCurrentUser();

      if (currentUser == null) {
        emit(LanguageError(message: 'User not found. Please login again.'));
        return;
      }

      // Extract user ID with comprehensive error handling
      dynamic userId = _extractUserId(currentUser);

      if (userId == null) {
        emit(LanguageError(
            message: 'User ID not available. Please login again.'));
        return;
      }

      // Call the language service to get user preferences
      final response = await languageService.getUserLanguagePreferences(
        userId,
        accessToken: accessToken,
      );

      if (response.statusCode == 200) {
        emit(LanguagePreferencesSuccess(preferences: response.data));
      } else {
        if (response.statusCode == 401) {
          emit(LanguageError(message: 'Session expired. Please login again.'));
        } else {
          emit(LanguageError(message: response.message));
        }
      }
    } catch (e) {
      emit(LanguageError(message: _handleError(e)));
    }
  }

  /// Helper method to extract user ID from user object
  dynamic _extractUserId(dynamic user) {
    try {
      // Try different common property names for user ID
      if (user.userId != null) return user.userId;
      if (user.id != null) return user.id;
      if (user.user_id != null) return user.user_id;
      if (user.userID != null) return user.userID;
      if (user.ID != null) return user.ID;

      // If user is a Map, try accessing as map
      if (user is Map) {
        return user['userId'] ??
            user['id'] ??
            user['user_id'] ??
            user['userID'] ??
            user['ID'];
      }

      // If all else fails, try to convert user object to string and look for patterns
      final userString = user.toString();
      print('User object string representation: $userString');

      return null;
    } catch (e) {
      print('Error extracting user ID: $e');
      return null;
    }
  }

  // /// Update user language preference with authentication
  // Future<void> updateLanguagePreference({
  //   required int languageId,
  //   required String proficiencyLevel,
  // }) async {
  //   try {
  //     emit(LanguageLoading());

  //     // Validate and refresh token if needed
  //     final isTokenValid = await authService.validateAndRefreshTokenIfNeeded();

  //     if (!isTokenValid) {
  //       emit(LanguageError(message: 'Authentication failed. Please login again.'));
  //       return;
  //     }

  //     // Get the access token
  //     final accessToken = await authService.getAccessToken();

  //     if (accessToken == null || accessToken.isEmpty) {
  //       emit(LanguageError(message: 'No access token available. Please login again.'));
  //       return;
  //     }

  //     // Get current user
  //     final currentUser = await authService.getCurrentUser();

  //     if (currentUser == null) {
  //       emit(LanguageError(message: 'User not found. Please login again.'));
  //       return;
  //     }

  //     // Call the language service to update preference
  //     final response = await languageService.updateLanguagePreference(
  //       userId: currentUser.userId,
  //       languageId: languageId,
  //       proficiencyLevel: proficiencyLevel,
  //       accessToken: accessToken,
  //     );

  //     if (response.statusCode == 200) {
  //       emit(LanguageUpdateSuccess(
  //         updatedPreferences: response.data,
  //         message: 'Language preference updated successfully',
  //       ));
  //     } else {
  //       if (response.statusCode == 401) {
  //         emit(LanguageError(message: 'Session expired. Please login again.'));
  //       } else {
  //         emit(LanguageError(message: response.message));
  //       }
  //     }
  //   } catch (e) {
  //     emit(LanguageError(message: _handleError(e)));
  //   }
  // }

  /// Check if user is authenticated
  Future<bool> checkAuthentication() async {
    try {
      return await authService.isUserAuthenticated();
    } catch (e) {
      return false;
    }
  }

  /// Get current user info
  Future<void> getCurrentUserInfo() async {
    try {
      final user = await authService.getCurrentUser();
      if (user == null) {
        emit(LanguageError(message: 'User not authenticated'));
      }
      // You can emit a specific state for user info if needed
    } catch (e) {
      emit(LanguageError(message: _handleError(e)));
    }
  }

  /// Reset state to initial
  void resetState() {
    emit(LanguageInitial());
  }

  /// Handle different types of errors
  String _handleError(dynamic error) {
    if (error is String) {
      return error;
    } else if (error.toString().contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    } else if (error.toString().contains('TimeoutException')) {
      return 'Request timeout. Please try again.';
    } else if (error.toString().contains('FormatException')) {
      return 'Invalid response format from server.';
    } else if (error.toString().contains('401') ||
        error.toString().contains('Unauthorized')) {
      return 'Session expired. Please login again.';
    } else if (error.toString().contains('403') ||
        error.toString().contains('Forbidden')) {
      return 'Access denied. You do not have permission to perform this action.';
    } else if (error.toString().contains('404') ||
        error.toString().contains('Not Found')) {
      return 'Requested resource not found.';
    } else if (error.toString().contains('500') ||
        error.toString().contains('Internal Server Error')) {
      return 'Server error. Please try again later.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}
