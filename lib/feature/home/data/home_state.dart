// auth_state.dart
import 'package:equatable/equatable.dart';
import 'package:e_learning_app/core/model/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
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
  List<Object?> get props => [user, accessToken];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthTokenExpired extends AuthState {
  final String message;

  const AuthTokenExpired({
    this.message = 'Session expired. Please login again.',
  });

  @override
  List<Object?> get props => [message];
}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}