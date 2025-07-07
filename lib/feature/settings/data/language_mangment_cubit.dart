import 'package:e_learning_app/feature/settings/data/language_mangment_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/core/service/language_service.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/core/model/language_model.dart';
import 'package:e_learning_app/core/model/language_request_model.dart';

class LanguageManagementCubit extends Cubit<LanguageManagementState> {
  final LanguageService _languageService;
  final AuthService _authService;

  List<Language> _languages = [];
  Set<int> _selectedLanguageIds = {};

  LanguageManagementCubit({
    required LanguageService languageService,
    required AuthService authService,
  })  : _languageService = languageService,
        _authService = authService,
        super(LanguageManagementInitial());

  List<Language> get languages => _languages;
  Set<int> get selectedLanguageIds => _selectedLanguageIds;

  Future<void> loadLanguages() async {
    try {
      emit(LanguageManagementLoading());

      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        emit(const LanguageManagementError('Authentication required'));
        return;
      }

      final response = await _languageService.getAllLanguages(
        accessToken: accessToken,
      );

      if (response.statusCode == 200) {
        _languages = response.data;
        _selectedLanguageIds.clear();
        emit(LanguageManagementLoaded(_languages));
      } else {
        emit(LanguageManagementError(
          response.message,
        ));
      }
    } catch (e) {
      emit(LanguageManagementError('Error loading languages: $e'));
    }
  }

  Future<void> addLanguages(List<AddLanguageRequest> languageRequests) async {
    try {
      emit(LanguageManagementLoading());

      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        emit(const LanguageManagementError('Authentication required'));
        return;
      }

      final response = await _languageService.addLanguages(
        languageRequests,
        accessToken: accessToken,
      );

      if (response.statusCode == 201) {
        _languages.addAll(response.data);
        emit(LanguageManagementLoaded(_languages));
        emit(LanguageManagementSuccess(
          response.message,
        ));
        // Reload to get fresh data
        await loadLanguages();
      } else {
        emit(LanguageManagementError(
          response.message,
        ));
      }
    } catch (e) {
      emit(LanguageManagementError('Error adding languages: $e'));
    }
  }

  Future<void> updateLanguages(
      List<UpdateLanguageRequest> languageRequests) async {
    try {
      emit(LanguageManagementLoading());

      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        emit(const LanguageManagementError('Authentication required'));
        return;
      }

      final response = await _languageService.updateLanguages(
        languageRequests,
        accessToken: accessToken,
      );

      if (response.statusCode == 200) {
        for (final updatedLanguage in response.data) {
          final index =
              _languages.indexWhere((lang) => lang.id == updatedLanguage.id);
          if (index != -1) {
            _languages[index] = updatedLanguage;
          }
        }
        emit(LanguageManagementLoaded(_languages));
        emit(LanguageManagementSuccess(
          response.message,
        ));
        await loadLanguages();
      } else {
        emit(LanguageManagementError(
          response.message,
        ));
      }
    } catch (e) {
      emit(LanguageManagementError('Error updating languages: $e'));
    }
  }

  Future<void> removeLanguages(List<int> languageIds) async {
    try {
      emit(LanguageManagementLoading());

      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        emit(const LanguageManagementError('Authentication required'));
        return;
      }

      final response = await _languageService.removeLanguages(
        languageIds,
        accessToken: accessToken,
      );

      if (response.statusCode == 200) {
        final deletedIds = response.data;
        _languages.removeWhere((lang) => deletedIds.contains(lang.id));
        _selectedLanguageIds.removeWhere((id) => deletedIds.contains(id));

        emit(LanguageManagementLoaded(_languages));
        emit(LanguageManagementSuccess(
          response.message,
        ));
        // Reload to get fresh data
        await loadLanguages();
      } else {
        emit(LanguageManagementError(
          response.message,
        ));
      }
    } catch (e) {
      emit(LanguageManagementError('Error removing languages: $e'));
    }
  }

  void toggleLanguageSelection(int languageId) {
    if (_selectedLanguageIds.contains(languageId)) {
      _selectedLanguageIds.remove(languageId);
    } else {
      _selectedLanguageIds.add(languageId);
    }
    emit(LanguageManagementLoaded(_languages));
  }

  void selectAllLanguages() {
    _selectedLanguageIds = _languages.map((lang) => lang.id).toSet();
    emit(LanguageManagementLoaded(_languages));
  }

  void clearSelection() {
    _selectedLanguageIds.clear();
    emit(LanguageManagementLoaded(_languages));
  }

  Language? getLanguageById(int id) {
    try {
      return _languages.firstWhere((lang) => lang.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Language> searchLanguages(String query) {
    if (query.isEmpty) return _languages;

    return _languages
        .where((lang) =>
            lang.name.toLowerCase().contains(query.toLowerCase()) ||
            lang.code.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  bool validateLanguageData(String name, String code) {
    if (name.trim().isEmpty || code.trim().isEmpty) {
      return false;
    }

    final existingNames =
        _languages.map((lang) => lang.name.toLowerCase()).toList();
    final existingCodes =
        _languages.map((lang) => lang.code.toLowerCase()).toList();

    return !existingNames.contains(name.toLowerCase()) &&
        !existingCodes.contains(code.toLowerCase());
  }

  Future<bool> checkAdminPermissions() async {
    try {
      return await _authService.hasRole('Admin');
    } catch (e) {
      return false;
    }
  }
}
