import 'package:e_learning_app/feature/language/data/language_state.dart';
import 'package:e_learning_app/feature/settings/data/interest_mangment_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'package:e_learning_app/core/service/interest_service.dart';
import 'package:e_learning_app/core/model/interest_update_request.dart';

class InterestManagementCubit extends Cubit<InterestManagementState> {
  final InterestService _interestService;
  final AuthService _authService;

  List<Interest> _interests = [];
  List<Interest> get interests => _interests;

  InterestManagementCubit({
    required InterestService interestService,
    required AuthService authService,
  })  : _interestService = interestService,
        _authService = authService,
        super(InterestManagementInitial());

  Future<void> loadInterests() async {
    try {
      emit(InterestManagementLoading());

      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        emit(const InterestManagementError('Access token not found'));
        return;
      }

      final response = await _interestService.getAllInterests(
        accessToken: accessToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        // Assuming the API returns a list of interests
        final List<dynamic> interestData = response.data is List
            ? response.data as List<dynamic>
            : (response.data as Map<String, dynamic>)['interests'] ?? [];

        _interests = interestData
            .map((json) => Interest.fromJson(json as Map<String, dynamic>))
            .toList();

        emit(InterestManagementLoaded(_interests));
      } else {
        emit(InterestManagementError(response.message));
      }
    } catch (e) {
      emit(InterestManagementError('Error loading interests: $e'));
    }
  }

  Future<void> addInterest(InterestAddRequest request) async {
    try {
      emit(InterestManagementLoading());

      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        emit(const InterestManagementError('Access token not found'));
        return;
      }

      final response = await _interestService.addInterest(
        request: request,
        accessToken: accessToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Reload interests to get the updated list
        await loadInterests();
        emit(const InterestManagementSuccess('Interest added successfully'));
      } else {
        emit(InterestManagementError(response.message));
      }
    } catch (e) {
      emit(InterestManagementError('Error adding interest: $e'));
    }
  }
}
