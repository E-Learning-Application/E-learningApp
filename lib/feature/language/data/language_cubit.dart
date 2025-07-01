import 'package:e_learning_app/feature/language/data/language_state.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/core/service/language_service.dart';
import 'package:e_learning_app/core/model/language_model.dart';
import 'package:e_learning_app/core/model/language_request_model.dart';

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

      final isTokenValid = await authService.validateAndRefreshTokenIfNeeded();
      if (!isTokenValid) {
        emit(LanguageError(
            message: 'Authentication failed. Please login again.'));
        return;
      }

      final accessToken = await authService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        emit(LanguageError(
            message: 'No access token available. Please login again.'));
        return;
      }

      final response =
          await languageService.getAllLanguages(accessToken: accessToken);

      if (response.statusCode == 200) {
        final languages = (response.data as List)
            .map((e) => Language.fromJson((e as dynamic).toJson()))
            .toList();
        emit(LanguageSuccess(languages: languages));
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

  /// Get user language preferences with authentication
  Future<void> getUserLanguagePreferences() async {
    try {
      emit(LanguageLoading());

      final isTokenValid = await authService.validateAndRefreshTokenIfNeeded();
      if (!isTokenValid) {
        emit(LanguageError(
            message: 'Authentication failed. Please login again.'));
        return;
      }

      final accessToken = await authService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        emit(LanguageError(
            message: 'No access token available. Please login again.'));
        return;
      }

      final currentUser = await authService.getCurrentUser();
      if (currentUser == null) {
        emit(LanguageError(message: 'User not found. Please login again.'));
        return;
      }

      dynamic userId = _extractUserId(currentUser);
      if (userId == null) {
        emit(LanguageError(
            message: 'User ID not available. Please login again.'));
        return;
      }

      final response = await languageService.getUserLanguagePreferences(
        userId,
        accessToken: accessToken,
      );

      if (response.statusCode == 200) {
        final preferences = (response.data as List)
            .map((e) => LanguagePreference.fromJson((e as dynamic).toJson()))
            .toList();
        emit(LanguagePreferencesSuccess(preferences: preferences));
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

  /// Update multiple user language preferences in bulk (FIXED)
  Future<void> updateUserLanguagePreferences({
    required List<LanguagePreferenceUpdate> preferences,
  }) async {
    try {
      emit(LanguageLoading());

      final isTokenValid = await authService.validateAndRefreshTokenIfNeeded();
      if (!isTokenValid) {
        emit(LanguageError(
            message: 'Authentication failed. Please login again.'));
        return;
      }

      final accessToken = await authService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        emit(LanguageError(
            message: 'No access token available. Please login again.'));
        return;
      }

      // Get current user to extract userId
      final currentUser = await authService.getCurrentUser();
      if (currentUser == null) {
        emit(LanguageError(message: 'User not found. Please login again.'));
        return;
      }

      dynamic userId = _extractUserId(currentUser);
      if (userId == null) {
        emit(LanguageError(
            message: 'User ID not available. Please login again.'));
        return;
      }

      // Convert preferences to UpdateLanguagePreferenceRequest objects
      final requestList = preferences
          .map((pref) => UpdateLanguagePreferenceRequest(
                userId: userId,
                languageId: pref.languageId,
                proficiencyLevel: pref.proficiencyLevel,
                isLearning: pref.isLearning,
              ))
          .toList();

      final response = await languageService.updateUserLanguagePreferences(
        requestList,
        accessToken: accessToken,
      );

      if (response.statusCode == 200) {
        final updatedPreferences = response.data as List<LanguagePreference>;

        emit(LanguageUpdateSuccess(
          updatedPreferences: updatedPreferences,
          message:
              response.message ?? 'Language preferences updated successfully',
        ));
      } else {
        if (response.statusCode == 401) {
          emit(LanguageError(message: 'Session expired. Please login again.'));
        } else {
          emit(LanguageError(
              message: response.message ?? 'Failed to update preferences'));
        }
      }
    } catch (e) {
      emit(LanguageError(message: _handleError(e)));
    }
  }

  /// Update single language preference (keeping for backward compatibility)
  Future<void> updateLanguagePreference({
    required int languageId,
    required String proficiencyLevel,
    bool isLearning = true,
  }) async {
    // Use the bulk update method with a single preference
    await updateUserLanguagePreferences(
      preferences: [
        LanguagePreferenceUpdate(
          languageId: languageId,
          proficiencyLevel: proficiencyLevel,
          isLearning: isLearning,
        ),
      ],
    );
  }

  /// Helper method to extract user ID from user object
  dynamic _extractUserId(dynamic user) {
    try {
      if (user.userId != null) return user.userId;
      if (user.id != null) return user.id;
      if (user.user_id != null) return user.user_id;
      if (user.userID != null) return user.userID;
      if (user.ID != null) return user.ID;

      if (user is Map) {
        return user['userId'] ??
            user['id'] ??
            user['user_id'] ??
            user['userID'] ??
            user['ID'];
      }

      final userString = user.toString();
      print('User object string representation: $userString');
      return null;
    } catch (e) {
      print('Error extracting user ID: $e');
      return null;
    }
  }

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

/// Helper class for language preference updates
class LanguagePreferenceUpdate {
  final int languageId;
  final String proficiencyLevel;
  final bool isLearning;

  LanguagePreferenceUpdate({
    required this.languageId,
    required this.proficiencyLevel,
    required this.isLearning,
  });
}
