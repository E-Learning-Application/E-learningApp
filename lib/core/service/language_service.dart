import 'package:e_learning_app/core/api/api_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'package:dio/dio.dart';

class Language {
  final int id;
  final String name;
  final String code;
  final String? flag; // Added flag field to match your original model

  Language({
    required this.id,
    required this.name,
    required this.code,
    this.flag,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      flag: json['flag'], // Handle flag from API
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'flag': flag,
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
      statusCode: json['statusCode'] ?? 200,
      message: json['message'] ?? 'Success',
    );
  }
}

class LanguageService {
  final ApiConsumer apiConsumer;

  LanguageService({required this.apiConsumer});

  /// Get all available languages with authentication
  Future<ApiResponse<List<Language>>> getAllLanguages({
    String? accessToken,
  }) async {
    try {
      final response = await apiConsumer.get(
        EndPoint.getAllLanguages,
        options: Options(
          headers: accessToken != null
              ? {'Authorization': 'Bearer $accessToken'}
              : null,
        ),
      );

      return ApiResponse.fromJson(
        response,
        (data) => (data as List)
            .map((language) => Language.fromJson(language))
            .toList(),
      );
    } catch (e) {
      print('Error in getAllLanguages: $e');
      rethrow;
    }
  }

  /// Get user language preferences with authentication
  Future<ApiResponse<List<LanguagePreference>>> getUserLanguagePreferences(
    int userId, {
    required String accessToken,
  }) async {
    try {
      final response = await apiConsumer.get(
        EndPoint.getUserLanguagePreferences,
        queryParameters: {'userId': userId},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      return ApiResponse.fromJson(
        response,
        (data) => (data as List)
            .map((pref) => LanguagePreference.fromJson(pref))
            .toList(),
      );
    } catch (e) {
      print('Error in getUserLanguagePreferences: $e');
      rethrow;
    }
  }

  /// Update user language preferences with authentication
  Future<ApiResponse<List<LanguagePreference>>> updateUserLanguagePreferences(
    List<UpdateLanguagePreferenceRequest> preferences, {
    required String accessToken,
  }) async {
    try {
      final response = await apiConsumer.put(
        EndPoint.updateUserLanguagePreferences,
        data: preferences.map((pref) => pref.toJson()).toList(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      return ApiResponse.fromJson(
        response,
        (data) => (data as List)
            .map((pref) => LanguagePreference.fromJson(pref))
            .toList(),
      );
    } catch (e) {
      print('Error in updateUserLanguagePreferences: $e');
      rethrow;
    }
  }

  /// Update a single language preference with authentication
  Future<ApiResponse<LanguagePreference>> updateSingleLanguagePreference({
    required int userId,
    required int languageId,
    required String proficiencyLevel,
    required bool isLearning,
    required String accessToken,
  }) async {
    try {
      final request = UpdateLanguagePreferenceRequest(
        languageId: languageId,
        proficiencyLevel: proficiencyLevel,
        isLearning: isLearning,
      );

      final response = await apiConsumer.put(
        '${EndPoint.updateUserLanguagePreferences}/$userId',
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      return ApiResponse.fromJson(
        response,
        (data) => LanguagePreference.fromJson(data),
      );
    } catch (e) {
      print('Error in updateSingleLanguagePreference: $e');
      rethrow;
    }
  }

  /// Create a language preference request object
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

//   /// Create a language preference with authentication
//   Future<ApiResponse<LanguagePreference>> createLanguagePreference({
//     required int userId,
//     required int languageId,
//     required String proficiencyLevel,
//     required bool isLearning,
//     required String accessToken,
//   }) async {
//     try {
//       final data = {
//         'userId': userId,
//         'languageId': languageId,
//         'proficiencyLevel': proficiencyLevel,
//         'isLearning': isLearning,
//       };

//       final response = await apiConsumer.post(
//         EndPoint.createLanguagePreference,
//         data: data,
//         options: Options(
//           headers: {
//             'Authorization': 'Bearer $accessToken',
//             'Content-Type': 'application/json',
//           },
//         ),
//       );

//       return ApiResponse.fromJson(
//         response,
//         (data) => LanguagePreference.fromJson(data),
//       );
//     } catch (e) {
//       print('Error in createLanguagePreference: $e');
//       rethrow;
//     }
//   }

//   /// Delete a language preference with authentication
//   Future<ApiResponse<bool>> deleteLanguagePreference({
//     required int userId,
//     required int languageId,
//     required String accessToken,
//   }) async {
//     try {
//       final response = await apiConsumer.delete(
//         '${EndPoint.deleteLanguagePreference}/$userId/$languageId',
//         options: Options(
//           headers: {
//             'Authorization': 'Bearer $accessToken',
//             'Content-Type': 'application/json',
//           },
//         ),
//       );

//       return ApiResponse.fromJson(
//         response,
//         (data) => true,
//       );
//     } catch (e) {
//       print('Error in deleteLanguagePreference: $e');
//       rethrow;
//     }
//   }

//   /// Get available proficiency levels
//   List<LanguageProficiencyLevel> getAvailableProficiencyLevels() {
//     return LanguageProficiencyLevel.values;
//   }

//   /// Get proficiency level by string value
//   LanguageProficiencyLevel? getProficiencyLevelByValue(String value) {
//     try {
//       return LanguageProficiencyLevel.values.firstWhere(
//         (level) => level.value.toLowerCase() == value.toLowerCase(),
//       );
//     } catch (e) {
//       return null;
//     }
//   }
// }
