import 'package:e_learning_app/core/api/api_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'language_service.dart'; // Import to use shared models

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

class LanguageAdminService {
  final ApiConsumer apiConsumer;

  LanguageAdminService({required this.apiConsumer});

  /// Add multiple languages to the platform
  /// Requires Admin role authentication
  Future<ApiResponse<List<Language>>> addLanguages(
    List<AddLanguageRequest> languages,
  ) async {
    try {
      final response = await apiConsumer.post(
        EndPoint.addLanguages,
        data: languages.map((lang) => lang.toJson()).toList(),
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

  /// Update multiple languages in the platform
  /// Requires Admin role authentication
  Future<ApiResponse<List<Language>>> updateLanguages(
    List<UpdateLanguageRequest> languages,
  ) async {
    try {
      final response = await apiConsumer.put(
        EndPoint.updateLanguages,
        data: languages.map((lang) => lang.toJson()).toList(),
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

  /// Remove multiple languages from the platform
  /// Requires Admin role authentication
  Future<ApiResponse<List<int>>> removeLanguages(
    List<int> languageIds,
  ) async {
    try {
      final response = await apiConsumer.delete(
        EndPoint.removeLanguages,
        data: languageIds,
      );

      return ApiResponse.fromJson(
        response,
        (data) => (data as List).map((id) => id as int).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Helper method to create an AddLanguageRequest
  AddLanguageRequest createAddLanguageRequest({
    required String name,
    required String code,
  }) {
    return AddLanguageRequest(
      name: name,
      code: code,
    );
  }

  /// Helper method to create an UpdateLanguageRequest
  UpdateLanguageRequest createUpdateLanguageRequest({
    required int id,
    required String name,
    required String code,
  }) {
    return UpdateLanguageRequest(
      id: id,
      name: name,
      code: code,
    );
  }
}