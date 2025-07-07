import 'package:e_learning_app/feature/language/data/language_state.dart';
import 'package:equatable/equatable.dart';

abstract class InterestManagementState extends Equatable {
  const InterestManagementState();

  @override
  List<Object?> get props => [];
}

class InterestManagementInitial extends InterestManagementState {}

class InterestManagementLoading extends InterestManagementState {}

class InterestManagementLoaded extends InterestManagementState {
  final List<Interest> interests;

  const InterestManagementLoaded(this.interests);

  @override
  List<Object?> get props => [interests];
}

class InterestManagementSuccess extends InterestManagementState {
  final String message;

  const InterestManagementSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class InterestManagementError extends InterestManagementState {
  final String message;

  const InterestManagementError(this.message);

  @override
  List<Object?> get props => [message];
}
