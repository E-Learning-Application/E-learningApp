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

    if (result['statusCode'] == 200) {
      emit(SettingsLogoutSuccess());
    } else {
      emit(SettingsLogoutFailure(error: result['message'] ?? 'Unknown error'));
    }
  } catch (e) {
    emit(SettingsLogoutFailure(error: 'Logout failed. Please try again.'));
    
    await Future.delayed(const Duration(seconds: 2));
    emit(SettingsLoaded());
  }
}

  Future<void> navigateToPayment() async {}

  Future<void> navigateToHistory() async {}

  Future<void> navigateToHelpCenter() async {}

  Future<void> navigateToContactUs() async {}

  Future<void> navigateToChangePassword() async {}
}