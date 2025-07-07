import 'package:e_learning_app/core/model/language_model.dart';
import 'package:equatable/equatable.dart';

class Interest extends Equatable {
  final int id;
  final String name;
  final String? description;

  const Interest({
    required this.id,
    required this.name,
    this.description,
  });

  factory Interest.fromJson(Map<String, dynamic> json) {
    return Interest(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  @override
  List<Object?> get props => [id, name, description];
}

class UserInterest extends Equatable {
  final int id;
  final int userId;
  final int interestId;
  final Interest interest;

  const UserInterest({
    required this.id,
    required this.userId,
    required this.interestId,
    required this.interest,
  });

  factory UserInterest.fromJson(Map<String, dynamic> json) {
    return UserInterest(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      interestId: json['interestId'] ?? 0,
      interest: Interest.fromJson(json['interest'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'interestId': interestId,
      'interest': interest.toJson(),
    };
  }

  @override
  List<Object?> get props => [id, userId, interestId, interest];
}

class InterestAddRequest extends Equatable {
  final String name;
  final String? description;

  const InterestAddRequest({
    required this.name,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
    };
  }

  @override
  List<Object?> get props => [name, description];
}

class UserInterestAddRequest extends Equatable {
  final int userId;
  final int interestId;

  const UserInterestAddRequest({
    required this.userId,
    required this.interestId,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'interestId': interestId,
    };
  }

  @override
  List<Object?> get props => [userId, interestId];
}

// Extended states for your existing LanguageState
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

// New states for Interest functionality
class InterestLoading extends LanguageState {}

class InterestSuccess extends LanguageState {
  final List<Interest> interests;

  const InterestSuccess({required this.interests});

  @override
  List<Object?> get props => [interests];
}

class UserInterestSuccess extends LanguageState {
  final List<UserInterest> userInterests;

  const UserInterestSuccess({required this.userInterests});

  @override
  List<Object?> get props => [userInterests];
}

class InterestAddSuccess extends LanguageState {
  final Interest interest;
  final String message;

  const InterestAddSuccess({
    required this.interest,
    required this.message,
  });

  @override
  List<Object?> get props => [interest, message];
}

class UserInterestAddSuccess extends LanguageState {
  final UserInterest userInterest;
  final String message;

  const UserInterestAddSuccess({
    required this.userInterest,
    required this.message,
  });

  @override
  List<Object?> get props => [userInterest, message];
}

class LanguageError extends LanguageState {
  final String message;

  const LanguageError({required this.message});

  @override
  List<Object?> get props => [message];
}
