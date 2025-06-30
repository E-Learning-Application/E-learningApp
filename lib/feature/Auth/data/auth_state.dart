// auth_state.dart - Updated with proper state hierarchy
import 'package:e_learning_app/core/model/user_model.dart';

abstract class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final User user;
  final String accessToken;

  const AuthAuthenticated({
    required this.user,
    required this.accessToken,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthAuthenticated &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          accessToken == other.accessToken;

  @override
  int get hashCode => user.hashCode ^ accessToken.hashCode;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

class AuthTokenExpired extends AuthState {
  final String? message;

  const AuthTokenExpired({this.message});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthTokenExpired &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

// Login specific states
class LoginLoading extends AuthState {
  const LoginLoading();
}

class LoginSuccess extends AuthState {
  final User user;
  final String accessToken;
  final String? message;

  const LoginSuccess({
    required this.user,
    required this.accessToken,
    this.message,
  });
}

class LoginFailure extends AuthState {
  final String message;

  const LoginFailure({required this.message});
}

// Register specific states
class RegisterLoading extends AuthState {
  const RegisterLoading();
}

class RegisterSuccess extends AuthState {
  final String message;
  final User? user;

  const RegisterSuccess({
    required this.message,
    this.user,
  });
}

class RegisterFailure extends AuthState {
  final String message;

  const RegisterFailure({required this.message});
}
