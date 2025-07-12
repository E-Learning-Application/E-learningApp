import 'dart:io';
import 'package:dio/dio.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'package:e_learning_app/feature/profile/data/user_state.dart';
import 'package:e_learning_app/feature/Auth/data/auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserCubit extends Cubit<UserState> {
  final DioConsumer dioConsumer;
  final AuthCubit authCubit;

  UserCubit({required this.dioConsumer, required this.authCubit})
      : super(UserInitial());

  Future<Map<String, String>?> _getAuthHeaders() async {
    final token = authCubit.accessToken;
    if (token != null) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
    }
    return null;
  }

  Future<bool> _ensureValidToken() async {
    try {
      if (!authCubit.isAuthenticated) {
        emit(UserError(message: 'User not authenticated'));
        return false;
      }

      await authCubit.validateAndRefreshToken();

      if (!authCubit.isAuthenticated) {
        emit(UserError(message: 'Authentication failed. Please login again.'));
        return false;
      }

      return true;
    } catch (e) {
      emit(UserError(message: 'Authentication error: ${e.toString()}'));
      return false;
    }
  }

  Future<void> getUserById(int userId) async {
    try {
      emit(UserLoading());

      if (!await _ensureValidToken()) return;

      final headers = await _getAuthHeaders();
      if (headers == null) {
        emit(UserError(message: 'No authentication token available'));
        return;
      }

      final response = await dioConsumer.get(
        '${EndPoint.user}/$userId',
        options: Options(headers: headers),
      );

      if (response['statusCode'] == 200) {
        final user = User.fromJson(response['data']);
        emit(UserSuccess(data: user));
      } else {
        emit(UserError(message: 'Failed to get user details'));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        emit(UserError(message: 'Unauthorized access. Please login again.'));
        authCubit.setUnauthenticated();
      } else {
        emit(UserError(message: 'Network error: ${e.message}'));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  Future<void> getAllUsers({int pageNo = 0, int pageSize = 10}) async {
    try {
      emit(UserLoading());

      if (!await _ensureValidToken()) return;

      final headers = await _getAuthHeaders();
      if (headers == null) {
        emit(UserError(message: 'No authentication token available'));
        return;
      }

      final response = await dioConsumer.get(
        '${EndPoint.user}/all',
        queryParameters: {
          'pageNo': pageNo,
          'pageSize': pageSize,
        },
        options: Options(headers: headers),
      );

      if (response['statusCode'] == 200) {
        final users = (response['data'] as List)
            .map((user) => User.fromJson(user))
            .toList();

        emit(UsersListSuccess(
          users: users,
          totalCount: response['totalCount'] ?? users.length,
        ));
      } else {
        emit(UserError(message: 'Failed to get users list'));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        emit(UserError(message: 'Unauthorized access. Please login again.'));
        authCubit.setUnauthenticated();
      } else {
        emit(UserError(message: 'Network error: ${e.message}'));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      emit(UserLoading());

      if (!await _ensureValidToken()) return;

      final headers = await _getAuthHeaders();
      if (headers == null) {
        emit(UserError(message: 'No authentication token available'));
        return;
      }

      final response = await dioConsumer.delete(
        '${EndPoint.user}/$userId',
        options: Options(headers: headers),
      );

      if (response['statusCode'] == 200) {
        emit(UserSuccess(
          data: null,
          message: response['message'] ?? 'User deleted successfully',
        ));
      } else {
        emit(UserError(message: 'Failed to delete user'));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        emit(UserError(message: 'Unauthorized access. Please login again.'));
        authCubit.setUnauthenticated();
      } else {
        emit(UserError(message: 'Network error: ${e.message}'));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  Future<void> updatePassword(UpdatePasswordRequest request) async {
    try {
      emit(UserLoading());

      if (!await _ensureValidToken()) return;

      final headers = await _getAuthHeaders();
      if (headers == null) {
        emit(UserError(message: 'No authentication token available'));
        return;
      }

      final response = await dioConsumer.put(
        '${EndPoint.user}/password',
        data: request.toJson(),
        options: Options(headers: headers),
      );

      if (response['statusCode'] == 200) {
        emit(UserSuccess(
          data: null,
          message: response['message'] ?? 'Password updated successfully',
        ));
      } else {
        emit(UserError(
            message: response['message'] ?? 'Failed to update password'));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        emit(UserError(message: 'Unauthorized access. Please login again.'));
        authCubit.setUnauthenticated();
      } else if (e.response?.statusCode == 400) {
        // Handle 400 errors with custom message from API
        final errorMessage = e.response?.data['message'] ?? 'Invalid request';
        emit(UserError(message: errorMessage));
      } else {
        emit(UserError(message: 'Network error: ${e.message}'));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  Future<void> updateUserProfile({
    String? username,
    String? bio,
    File? image,
  }) async {
    try {
      emit(UserLoading());

      if (!await _ensureValidToken()) return;

      final token = authCubit.accessToken;
      if (token == null) {
        emit(UserError(message: 'No authentication token available'));
        return;
      }

      // Get current user to ensure we always have the username
      final currentUser = authCubit.currentUser;
      if (currentUser == null) {
        emit(UserError(message: 'Current user not available'));
        return;
      }

      Map<String, dynamic> formData = {};

      // Always include the username - use the new one if provided, otherwise use current
      final usernameToSend = username ?? currentUser.username;
      formData['Username'] = usernameToSend;

      if (bio != null) {
        formData['Bio'] = bio;
      }

      if (image != null) {
        formData['Image'] = await MultipartFile.fromFile(
          image.path,
          filename: image.path.split('/').last,
        );
      }

      final response = await dioConsumer.put(
        EndPoint.user,
        data: formData,
        isFromData: true,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response['statusCode'] == 200) {
        final updatedUser = User.fromJson(response['data']);
        emit(UserSuccess(
          data: updatedUser,
          message: response['message'] ?? 'User updated successfully',
        ));
      } else {
        emit(UserError(message: 'Failed to update user profile'));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        emit(UserError(message: 'Unauthorized access. Please login again.'));
        authCubit.setUnauthenticated();
      } else if (e.response?.statusCode == 400) {
        // Handle 400 errors with custom message from API
        final errorData = e.response?.data;
        if (errorData is Map<String, dynamic> &&
            errorData.containsKey('errors')) {
          final errors = errorData['errors'] as Map<String, dynamic>;
          final errorMessages = errors.values
              .expand((e) => e is List ? e : [e])
              .where((e) => e is String)
              .cast<String>()
              .join(', ');
          emit(UserError(
              message: errorMessages.isNotEmpty
                  ? errorMessages
                  : 'Invalid request'));
        } else {
          emit(UserError(message: 'Invalid request'));
        }
      } else {
        emit(UserError(message: 'Network error: ${e.message}'));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  Future<void> reportUser({
    required int reportedId,
    required String reason,
  }) async {
    try {
      emit(UserLoading());

      if (!await _ensureValidToken()) return;

      final headers = await _getAuthHeaders();
      if (headers == null) {
        emit(UserError(message: 'No authentication token available'));
        return;
      }

      final response = await dioConsumer.post(
        '${EndPoint.user}/report',
        data: {
          'ReportedId': reportedId,
          'Reason': reason,
        },
        options: Options(headers: headers),
      );

      if (response['statusCode'] == 200) {
        emit(UserSuccess(
          data: null,
          message: 'User reported successfully',
        ));
      } else {
        emit(UserError(message: 'Failed to report user'));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        emit(UserError(message: 'Unauthorized access. Please login again.'));
        authCubit.setUnauthenticated();
      } else {
        emit(UserError(message: 'Network error: ${e.message}'));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  Future<void> getCurrentUserProfile() async {
    try {
      emit(UserLoading());

      if (!await _ensureValidToken()) return;

      final headers = await _getAuthHeaders();
      if (headers == null) {
        emit(UserError(message: 'No authentication token available'));
        return;
      }

      final currentUser = authCubit.currentUser;
      if (currentUser?.userId == null) {
        emit(UserError(message: 'Current user ID not available'));
        return;
      }

      final response = await dioConsumer.get(
        '${EndPoint.user}/${currentUser!.userId}',
        options: Options(headers: headers),
      );

      if (response['statusCode'] == 200) {
        final user = User.fromJson(response['data']);
        emit(UserSuccess(data: user));
      } else {
        emit(UserError(message: 'Failed to get user profile'));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        emit(UserError(message: 'Unauthorized access. Please login again.'));
        authCubit.setUnauthenticated();
      } else {
        emit(UserError(message: 'Network error: ${e.message}'));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  void clearState() {
    emit(UserInitial());
  }
}
