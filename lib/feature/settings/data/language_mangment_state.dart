import 'package:equatable/equatable.dart';
import 'package:e_learning_app/core/model/language_model.dart';

abstract class LanguageManagementState extends Equatable {
  const LanguageManagementState();

  @override
  List<Object?> get props => [];
}

class LanguageManagementInitial extends LanguageManagementState {}

class LanguageManagementLoading extends LanguageManagementState {}

class LanguageManagementLoaded extends LanguageManagementState {
  final List<Language> languages;

  const LanguageManagementLoaded(this.languages);

  @override
  List<Object?> get props => [languages];
}

class LanguageManagementSuccess extends LanguageManagementState {
  final String message;

  const LanguageManagementSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class LanguageManagementError extends LanguageManagementState {
  final String message;

  const LanguageManagementError(this.message);

  @override
  List<Object?> get props => [message];
}

// Additional states for specific operations
class LanguageManagementAdding extends LanguageManagementState {}

class LanguageManagementUpdating extends LanguageManagementState {}

class LanguageManagementDeleting extends LanguageManagementState {}

class LanguageManagementSelectionChanged extends LanguageManagementState {
  final Set<int> selectedLanguageIds;

  const LanguageManagementSelectionChanged(this.selectedLanguageIds);

  @override
  List<Object?> get props => [selectedLanguageIds];
}
