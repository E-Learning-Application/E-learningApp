import 'package:equatable/equatable.dart';

class UpdateLanguagePreferenceRequest {
  final int languageId;
  final String proficiencyLevel;
  final bool isLearning;

  UpdateLanguagePreferenceRequest({
    required this.languageId,
    required this.proficiencyLevel,
    required this.isLearning,
    required userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'LanguageId': languageId,
      'proficiencyLevel': proficiencyLevel,
      'IsLearning': isLearning,
    };
  }
}

class UpdateLanguageRequest {
  final int id;
  final String name;
  final String code;

  UpdateLanguageRequest({
    required this.id,
    required this.name,
    required this.code,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Code': code,
    };
  }
}

class AddLanguageRequest {
  final String name;
  final String code;

  AddLanguageRequest({
    required this.name,
    required this.code,
  });

  Map<String, dynamic> toJson() {
    return {
      'Name': name,
      'Code': code,
    };
  }
}
