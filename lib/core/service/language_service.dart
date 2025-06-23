import 'package:e_learning_app/core/api/api_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
    };
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

class UpdateLanguagePreferenceRequest {
  final int languageId;
  final String proficiencyLevel;
  final bool isLearning;

  UpdateLanguagePreferenceRequest({
    required this.languageId,
    required this.proficiencyLevel,
    required this.isLearning,
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

enum LanguageProficiencyLevel {
  basic('Basic'),
  conversational('Conversational'),
  fluent('Fluent'),
  native('Native');

  const LanguageProficiencyLevel(this.value);
  final String value;
}

// API Response Model
class ApiResponse<T> {
  final T data;
  final int statusCode;
  final String message;

  ApiResponse({
    required this.data,
    required this.statusCode,
    required this.message,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return ApiResponse(
      data: fromJsonT(json['data']),
      statusCode: json['statusCode'],
      message: json['message'],
    );
  }
}

class LanguageService {
  final ApiConsumer apiConsumer;

  LanguageService({required this.apiConsumer});

  Future<ApiResponse<List<Language>>> getAllLanguages() async {
    try {
      final response = await apiConsumer.get(
        EndPoint.getAllLanguages,
      );

      return ApiResponse.fromJson(
        response,
        (data) => (data as List)
            .map((language) => Language.fromJson(language))
            .toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<ApiResponse<List<LanguagePreference>>> getUserLanguagePreferences(
    int userId,
  ) async {
    try {
      final response = await apiConsumer.get(
        EndPoint.getUserLanguagePreferences,
        queryParameters: {'userId': userId},
      );

      return ApiResponse.fromJson(
        response,
        (data) => (data as List)
            .map((pref) => LanguagePreference.fromJson(pref))
            .toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<ApiResponse<List<LanguagePreference>>> updateUserLanguagePreferences(
    List<UpdateLanguagePreferenceRequest> preferences,
  ) async {
    try {
      final response = await apiConsumer.put(
        EndPoint.updateUserLanguagePreferences,
        data: preferences.map((pref) => pref.toJson()).toList(),
      );

      return ApiResponse.fromJson(
        response,
        (data) => (data as List)
            .map((pref) => LanguagePreference.fromJson(pref))
            .toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  UpdateLanguagePreferenceRequest createLanguagePreferenceRequest({
    required int languageId,
    required LanguageProficiencyLevel proficiencyLevel,
    required bool isLearning,
  }) {
    return UpdateLanguagePreferenceRequest(
      languageId: languageId,
      proficiencyLevel: proficiencyLevel.value,
      isLearning: isLearning,
    );
  }
}