import 'package:e_learning_app/core/model/language_model.dart';
import 'package:equatable/equatable.dart';

abstract class LanguageState extends Equatable {
  const LanguageState();

  @override
  List<Object?> get props => [];
}

class LanguageInitial extends LanguageState {}

class LanguageLoading extends LanguageState {}

class LanguageSuccess extends LanguageState {
  final List<Language> languages;

  const LanguageSuccess({required this.languages});

  @override
  List<Object?> get props => [languages];
}

class LanguagePreferencesSuccess extends LanguageState {
  final List<LanguagePreference> preferences;

  const LanguagePreferencesSuccess({required this.preferences});

  @override
  List<Object?> get props => [preferences];
}

class LanguageUpdateSuccess extends LanguageState {
  final List<LanguagePreference> updatedPreferences;
  final String message;

  const LanguageUpdateSuccess({
    required this.updatedPreferences,
    required this.message,
  });

  @override
  List<Object?> get props => [updatedPreferences, message];
}

class LanguageError extends LanguageState {
  final String message;

  const LanguageError({required this.message});

  @override
  List<Object?> get props => [message];
}
