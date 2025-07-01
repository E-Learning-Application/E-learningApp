import 'package:dio/dio.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'package:e_learning_app/core/model/api_response_model.dart';
import 'package:e_learning_app/core/model/language_model.dart';
import 'package:e_learning_app/core/model/language_request_model.dart';

class LanguageService {
  final DioConsumer dioConsumer;

  LanguageService({required this.dioConsumer});

  Future<ApiResponse<List<Language>>> getAllLanguages({
    String? accessToken,
  }) async {
    try {
      final response = await dioConsumer.get(
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

  Future<ApiResponse<List<Language>>> addLanguages(
    List<AddLanguageRequest> languages, {
    required String accessToken,
  }) async {
    try {
      final response = await dioConsumer.post(
        EndPoint.addLanguages,
        data: languages.map((lang) => lang.toJson()).toList(),
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
            .map((language) => Language.fromJson(language))
            .toList(),
      );
    } catch (e) {
      print('Error in addLanguages: $e');
      rethrow;
    }
  }

  Future<ApiResponse<List<Language>>> updateLanguages(
    List<UpdateLanguageRequest> languages, {
    required String accessToken,
  }) async {
    try {
      final response = await dioConsumer.put(
        EndPoint.updateLanguages,
        data: languages.map((lang) => lang.toJson()).toList(),
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
            .map((language) => Language.fromJson(language))
            .toList(),
      );
    } catch (e) {
      print('Error in updateLanguages: $e');
      rethrow;
    }
  }

  Future<ApiResponse<List<int>>> removeLanguages(
    List<int> languageIds, {
    required String accessToken,
  }) async {
    try {
      final response = await dioConsumer.delete(
        EndPoint.removeLanguages,
        data: languageIds,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      return ApiResponse.fromJson(
        response,
        (data) => (data as List).map((id) => id as int).toList(),
      );
    } catch (e) {
      print('Error in removeLanguages: $e');
      rethrow;
    }
  }

  Future<ApiResponse<List<LanguagePreference>>> getUserLanguagePreferences(
    int userId, {
    required String accessToken,
  }) async {
    try {
      final response = await dioConsumer.get(
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

  Future<ApiResponse<List<LanguagePreference>>> updateUserLanguagePreferences(
    List<UpdateLanguagePreferenceRequest> preferences, {
    required String accessToken,
  }) async {
    try {
      final response = await dioConsumer.put(
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

  Future<ApiResponse<List<LanguagePreference>>> updateLanguagePreference({
    required int userId,
    required int languageId,
    required String proficiencyLevel,
    required bool isLearning,
    required String accessToken,
  }) {
    return updateUserLanguagePreferences(
      [
        UpdateLanguagePreferenceRequest(
          userId: userId,
          languageId: languageId,
          proficiencyLevel: proficiencyLevel,
          isLearning: isLearning,
        )
      ],
      accessToken: accessToken,
    );
  }
}
