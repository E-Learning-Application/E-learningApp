import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final AuthService _authService;

  SettingsCubit({required AuthService authService})
      : _authService = authService,
        super(SettingsInitial());

  Future<void> initializeSettings() async {
    emit(SettingsLoading());
    try {
      final isAdmin = await _authService.hasRole('Admin');
      emit(SettingsLoaded(isAdmin: isAdmin));
    } catch (e) {
      emit(SettingsLoaded(isAdmin: false));
    }
  }

  Future<void> logout() async {
    try {
      emit(SettingsLogoutLoading());
      final result = await _authService.logout();
      if (result['statusCode'] == 200) {
        emit(SettingsLogoutSuccess());
      } else {
        emit(
            SettingsLogoutFailure(error: result['message'] ?? 'Unknown error'));
      }
    } catch (e) {
      emit(SettingsLogoutFailure(error: 'Logout failed. Please try again.'));
      await Future.delayed(const Duration(seconds: 2));
      emit(SettingsLoaded());
    }
  }

  Future<void> navigateToPayment() async {}

  Future<void> navigateToHistory() async {}

  Future<void> navigateToLanguageSettings() async {
    try {
      final isAdmin = await _authService.hasRole('Admin');
      if (!isAdmin) {
        emit(const SettingsError(
            message: 'Access denied. Admin privileges required.'));
        return;
      }
    } catch (e) {
      emit(SettingsError(message: 'Error checking permissions: $e'));
    }
  }

  Future<void> navigateToHelpCenter() async {}

  Future<void> navigateToContactUs() async {
    // TODO: Implement contact us navigation
  }

  Future<void> navigateToChangePassword() async {}

  Future<bool> isCurrentUserAdmin() async {
    try {
      return await _authService.hasRole('Admin');
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasRole(String role) async {
    try {
      return await _authService.hasRole(role);
    } catch (e) {
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      return await _authService.getAccessToken();
    } catch (e) {
      return null;
    }
  }
}
