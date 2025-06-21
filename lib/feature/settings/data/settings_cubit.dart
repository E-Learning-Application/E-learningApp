import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final AuthService _authService;

  SettingsCubit({required AuthService authService})
      : _authService = authService,
        super(SettingsInitial());

  void initializeSettings() {
    emit(SettingsLoaded());
  }

 Future<void> logout() async {
  try {
    emit(SettingsLogoutLoading());
    
    final result = await _authService.logout();
    
    // Check if logout was successful
    if (result['success'] == true) {
      print('Logout completed: ${result['message']}');
      emit(SettingsLogoutSuccess());
    } else {
      emit(SettingsLogoutFailure(error: result['message'] ?? 'Unknown error'));
    }
  } catch (e) {
    print('Logout error in cubit: $e');
    emit(SettingsLogoutFailure(error: 'Logout failed. Please try again.'));
    
    // Reset to loaded state after showing error
    await Future.delayed(const Duration(seconds: 2));
    emit(SettingsLoaded());
  }
}

  Future<void> navigateToPayment() async {
    // TODO: Implement payment navigation
  }

  Future<void> navigateToHistory() async {
    // TODO: Implement history navigation
  }

  Future<void> navigateToHelpCenter() async {
    // TODO: Implement help center navigation
  }

  Future<void> navigateToContactUs() async {
    // TODO: Implement contact us navigation
  }

  Future<void> navigateToChangePassword() async {
    // TODO: Implement change password navigation
  }
}