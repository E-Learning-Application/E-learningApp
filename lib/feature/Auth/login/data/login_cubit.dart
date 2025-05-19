import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthService _authService;

  LoginCubit({required AuthService authService})
      : _authService = authService,
        super(LoginInitial());

  Future<void> login(String usernameOrEmail, String password) async {
    emit(LoginLoading());

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

  Future<void> checkAuthStatus() async {
    emit(LoginLoading());

    try {
      final isAuthenticated = await _authService.isUserAuthenticated();

      if (isAuthenticated) {
        final user = await _authService.getCurrentUser();
        final accessToken = await _authService.getAccessToken();

        if (user != null && accessToken != null) {
          emit(LoginSuccess(user: user, accessToken: accessToken));
        } else {
          emit(LoginInitial());
        }
      } else {
        final tokenRefreshed = await _authService.refreshTokenIfNeeded();

        if (tokenRefreshed) {
          final user = await _authService.getCurrentUser();
          final accessToken = await _authService.getAccessToken();

          if (user != null && accessToken != null) {
            emit(LoginSuccess(user: user, accessToken: accessToken));
          } else {
            emit(LoginInitial());
          }
        } else {
          emit(LoginInitial());
        }
      }
    } catch (e) {
      emit(LoginFailure(message: 'Auth check failed: ${e.toString()}'));
    }
  }

  Future<void> logout() async {
    emit(LoginLoading());

    try {
      await _authService.logout();
      emit(LoginInitial());
    } catch (e) {
      emit(LoginFailure(message: 'Logout failed: ${e.toString()}'));
    }
  }
}
