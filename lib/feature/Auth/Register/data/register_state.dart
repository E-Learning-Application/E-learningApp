import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:equatable/equatable.dart';

abstract class RegisterState extends Equatable {
  const RegisterState();
  
  @override
  List<Object?> get props => [];
}

class RegisterInitial extends RegisterState {}

class RegisterLoading extends RegisterState {}

class RegisterSuccess extends RegisterState {
  final User user;
  final String message;
  
  const RegisterSuccess({required this.user, required this.message});
  
  @override
  List<Object?> get props => [user, message];
}

class RegisterFailure extends RegisterState {
  final String message;
  
  const RegisterFailure({required this.message});
  
  @override
  List<Object?> get props => [message];
}