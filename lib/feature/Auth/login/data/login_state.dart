import 'package:e_learning_app/core/model/user_model.dart';
import 'package:equatable/equatable.dart';

abstract class LoginState extends Equatable {
  const LoginState();
  
  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final User user;
  final String accessToken;
  
  const LoginSuccess({required this.user, required this.accessToken});
  
  @override
  List<Object?> get props => [user, accessToken];
}

class LoginFailure extends LoginState {
  final String message;
  
  const LoginFailure({required this.message});
  
  @override
  List<Object?> get props => [message];
}