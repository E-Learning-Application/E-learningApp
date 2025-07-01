import 'package:e_learning_app/core/model/language_model.dart';
import 'package:e_learning_app/core/model/language_request_model.dart';

class LanguageHelper {
  /// Create a language preference request object
  static UpdateLanguagePreferenceRequest createLanguagePreferenceRequest(
      {required int languageId,
      required LanguageProficiencyLevel proficiencyLevel,
      required bool isLearning,
      required int userId}) {
    return UpdateLanguagePreferenceRequest(
      languageId: languageId,
      proficiencyLevel: proficiencyLevel.value,
      isLearning: isLearning,
      userId: userId,
    );
  }

  /// Helper method to create an AddLanguageRequest
  static AddLanguageRequest createAddLanguageRequest({
    required String name,
    required String code,
  }) {
    return AddLanguageRequest(
      name: name,
      code: code,
    );
  }

  /// Helper method to create an UpdateLanguageRequest
  static UpdateLanguageRequest createUpdateLanguageRequest({
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

  /// Get available proficiency levels
  static List<LanguageProficiencyLevel> getAvailableProficiencyLevels() {
    return LanguageProficiencyLevel.values;
  }

  /// Get proficiency level by string value
  static LanguageProficiencyLevel? getProficiencyLevelByValue(String value) {
    try {
      return LanguageProficiencyLevel.values.firstWhere(
        (level) => level.value.toLowerCase() == value.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Validate language code format (basic validation)
  static bool isValidLanguageCode(String code) {
    // Basic validation for ISO 639-1 (2-letter) or ISO 639-2 (3-letter) codes
    final regex = RegExp(r'^[a-z]{2,3}$', caseSensitive: false);
    return regex.hasMatch(code);
  }

  /// Get display text for proficiency level
  static String getProficiencyDisplayText(LanguageProficiencyLevel level) {
    switch (level) {
      case LanguageProficiencyLevel.basic:
        return 'Basic - Can understand and use simple phrases';
      case LanguageProficiencyLevel.conversational:
        return 'Conversational - Can handle everyday conversations';
      case LanguageProficiencyLevel.fluent:
        return 'Fluent - Can communicate effectively in most situations';
      case LanguageProficiencyLevel.native:
        return 'Native - Complete fluency and understanding';
    }
  }
}
