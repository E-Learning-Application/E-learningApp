import 'package:equatable/equatable.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {}

class SettingsLogoutLoading extends SettingsState {}

class SettingsLogoutSuccess extends SettingsState {}

class SettingsLogoutFailure extends SettingsState {
  final String error;

  const SettingsLogoutFailure({required this.error});

  @override
  List<Object?> get props => [error];
}

class SettingsError extends SettingsState {
  final String message;

  const SettingsError({required this.message});

  @override
  List<Object?> get props => [message];
}