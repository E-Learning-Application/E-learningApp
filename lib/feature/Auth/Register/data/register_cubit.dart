import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'register_state.dart';

class RegisterCubit extends Cubit<RegisterState> {
  final AuthService _authService;

  RegisterCubit({required AuthService authService})
      : _authService = authService,
        super(RegisterInitial());

  Future<void> register({
  required String username,
  required String email,
  required String password,
  required String confirmPassword,
}) async {
  emit(RegisterLoading());
  try {
    if (password != confirmPassword) {
      emit(const RegisterFailure(message: 'Passwords do not match'));
      return;
    }
    if (!isPasswordStrong(password)) {
      emit(const RegisterFailure(
          message:
              'Password is not strong enough. It should contain at least 8 characters, including uppercase, lowercase, numbers, and special characters.'));
      return;
    }
    if (!isEmailValid(email)) {
      emit(const RegisterFailure(
          message: 'Please enter a valid email address'));
      return;
    }
    
    final response = await _authService.register(
      username,
      email,
      password,
      confirmPassword,
    );
    
    // Handle both success (201) and created (200) status codes
    if (response.statusCode == 201 || response.statusCode == 200) {
      emit(RegisterSuccess(
        user: response.user,
        message: response.message ?? 'Registration successful!',
      ));
    } else {
      // Handle error status codes
      emit(RegisterFailure(
        message: response.message ?? 'Registration failed. Please try again.',
      ));
    }
  } catch (e) {
    print('Register cubit error: $e');
    emit(RegisterFailure(message: 'Registration failed: ${e.toString()}'));
  }
}

  void reset() {
    emit(RegisterInitial());
  }

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
