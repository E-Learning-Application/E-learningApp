import 'package:equatable/equatable.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final bool isAdmin;

  const SettingsLoaded({this.isAdmin = false});

  @override
  List<Object?> get props => [isAdmin];
}

class SettingsHistoryLoaded extends SettingsState {
  final List<Map<String, dynamic>> matchHistory;

  const SettingsHistoryLoaded({required this.matchHistory});

  @override
  List<Object?> get props => [matchHistory];
}

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
