import 'package:e_learning_app/core/service/language_service.dart';
import 'package:e_learning_app/feature/language/data/language_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LanguageCubit extends Cubit<LanguageState> {
  final LanguageService languageService;

  LanguageCubit({required this.languageService}) : super(LanguageInitial());

  /// Get all available languages
  Future<void> getAllLanguages() async {
    try {
      emit(LanguageLoading());
      
      final response = await languageService.getAllLanguages();
      
      if (response.statusCode == 200) {
        emit(LanguageSuccess(languages: response.data));
      } else {
        emit(LanguageError(message: response.message));
      }
    } catch (e) {
      emit(LanguageError(message: _handleError(e)));
    }
  }

  /// Reset state to initial
  void resetState() {
    emit(LanguageInitial());
  }

  /// Handle different types of errors
  String _handleError(dynamic error) {
    if (error is String) {
      return error;
    } else if (error.toString().contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    } else if (error.toString().contains('TimeoutException')) {
      return 'Request timeout. Please try again.';
    } else if (error.toString().contains('FormatException')) {
      return 'Invalid response format from server.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}