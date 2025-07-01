abstract class UserState {}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserSuccess extends UserState {
  final dynamic data;
  final String? message;

  UserSuccess({required this.data, this.message});
}

class UserError extends UserState {
  final String message;

  UserError({required this.message});
}

class UsersListSuccess extends UserState {
  final List<dynamic> users;
  final int totalCount;

  UsersListSuccess({required this.users, required this.totalCount});
}

class User {
  final int id;
  final String username;
  final String? imagePath;
  final String? bio;
  final List<LanguagePreference>? languagePreferences;

  User({
    required this.id,
    required this.username,
    this.imagePath,
    this.bio,
    this.languagePreferences,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      imagePath: json['imagePath'],
      bio: json['bio'],
      languagePreferences: json['languagePreferences'] != null
          ? (json['languagePreferences'] as List)
              .map((e) => LanguagePreference.fromJson(e))
              .toList()
          : null,
    );
  }
}

class LanguagePreference {
  final Language language;
  final String proficiencyLevel;
  final bool isLearning;

  LanguagePreference({
    required this.language,
    required this.proficiencyLevel,
    required this.isLearning,
  });

  factory LanguagePreference.fromJson(Map<String, dynamic> json) {
    return LanguagePreference(
      language: Language.fromJson(json['language']),
      proficiencyLevel: json['proficiencyLevel'],
      isLearning: json['isLearning'],
    );
  }
}

class Language {
  final int id;
  final String name;
  final String code;

  Language({
    required this.id,
    required this.name,
    required this.code,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      id: json['id'],
      name: json['name'],
      code: json['code'],
    );
  }
}

class UpdatePasswordRequest {
  final String currentPassword;
  final String newPassword;
  final String confirmNewPassword;

  UpdatePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmNewPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'CurrentPassword': currentPassword,
      'NewPassword': newPassword,
      'ConfirmNewPassword': confirmNewPassword,
    };
  }
}
