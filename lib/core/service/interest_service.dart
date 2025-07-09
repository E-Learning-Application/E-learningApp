import 'package:dio/dio.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'package:e_learning_app/core/model/api_response_model.dart';
import 'package:e_learning_app/feature/language/data/language_state.dart';

class InterestService {
  final DioConsumer _dioConsumer;

  InterestService({required DioConsumer dioConsumer})
      : _dioConsumer = dioConsumer;

  Future<ApiResponse> getAllInterests({
    required String accessToken,
  }) async {
    try {
      print('DEBUG: Getting all interests');

      final response = await _dioConsumer.get(
        EndPoint.getAllInterests,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('DEBUG: Get all interests response: $response');
      print('DEBUG: Response type: ${response.runtimeType}');

      // Handle the case where response is a List instead of Map
      if (response is List) {
        print('DEBUG: Response is a List, creating ApiResponse directly');

        // Filter out invalid interests (empty names, null values, etc.)
        final validInterests = response.where((item) {
          if (item is Map<String, dynamic>) {
            final name = item['name'];
            final id = item['id'];

            // Check if name is not null, not empty, and not just whitespace
            bool isValid =
                name != null && name.toString().trim().isNotEmpty && id != null;

            print(
                'DEBUG: Interest validation - ID: $id, Name: "$name", Valid: $isValid');
            return isValid;
          }
          return false;
        }).toList();

        print(
            'DEBUG: Filtered ${response.length} interests down to ${validInterests.length} valid ones');
        print('DEBUG: Valid interests: $validInterests');

        return ApiResponse(
          statusCode: 200,
          message: 'Success',
          data: validInterests,
        );
      } else if (response is Map<String, dynamic>) {
        print('DEBUG: Response is a Map, using fromJson');

        // Check if the map has a data field that contains the interests
        if (response.containsKey('data') && response['data'] is List) {
          final List<dynamic> interestsList = response['data'];
          final validInterests = interestsList.where((item) {
            if (item is Map<String, dynamic>) {
              final name = item['name'];
              final id = item['id'];

              bool isValid = name != null &&
                  name.toString().trim().isNotEmpty &&
                  id != null;

              print(
                  'DEBUG: Interest validation - ID: $id, Name: "$name", Valid: $isValid');
              return isValid;
            }
            return false;
          }).toList();

          print(
              'DEBUG: Filtered ${interestsList.length} interests down to ${validInterests.length} valid ones');

          return ApiResponse(
            statusCode: 200,
            message: 'Success',
            data: validInterests,
          );
        }

        return ApiResponse.fromJson(response, (data) => data);
      } else {
        print('DEBUG: Unexpected response type: ${response.runtimeType}');
        return ApiResponse(
          statusCode: 200,
          message: 'Success',
          data: response,
        );
      }
    } on DioException catch (e) {
      print('DEBUG: DioException in getAllInterests: ${e.toString()}');
      print('DEBUG: Response data: ${e.response?.data}');
      print('DEBUG: Status code: ${e.response?.statusCode}');

      return ApiResponse(
        statusCode: e.response?.statusCode ?? 500,
        message: _extractErrorMessage(e),
        data: null,
      );
    } catch (e) {
      print('DEBUG: General exception in getAllInterests: ${e.toString()}');
      print('DEBUG: Exception type: ${e.runtimeType}');
      return ApiResponse(
        statusCode: 500,
        message: 'An unexpected error occurred: ${e.toString()}',
        data: null,
      );
    }
  }

  Future<ApiResponse> addInterest({
    required InterestAddRequest request,
    required String accessToken,
  }) async {
    try {
      print('DEBUG: Adding interest with request: ${request.toJson()}');

      final response = await _dioConsumer.post(
        EndPoint.addInterest,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('DEBUG: Add interest response: $response');
      return ApiResponse.fromJson(response, (data) => data);
    } on DioException catch (e) {
      print('DEBUG: DioException in addInterest: ${e.toString()}');
      print('DEBUG: Response data: ${e.response?.data}');
      print('DEBUG: Status code: ${e.response?.statusCode}');

      return ApiResponse(
        statusCode: e.response?.statusCode ?? 500,
        message: _extractErrorMessage(e),
        data: null,
      );
    } catch (e) {
      print('DEBUG: General exception in addInterest: ${e.toString()}');
      return ApiResponse(
        statusCode: 500,
        message: 'An unexpected error occurred: ${e.toString()}',
        data: null,
      );
    }
  }

  Future<ApiResponse> addUserInterest({
    required UserInterestAddRequest request,
    required String accessToken,
  }) async {
    try {
      print('DEBUG: Adding user interest with request: ${request.toJson()}');
      print(
          'DEBUG: Access token (first 20 chars): ${accessToken.substring(0, 20)}...');

      final response = await _dioConsumer.post(
        EndPoint.addUserInterest,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('DEBUG: Add user interest response: $response');
      return ApiResponse.fromJson(response, (data) => data);
    } on DioException catch (e) {
      print('DEBUG: DioException in addUserInterest: ${e.toString()}');
      print('DEBUG: Response data: ${e.response?.data}');
      print('DEBUG: Status code: ${e.response?.statusCode}');
      print('DEBUG: Response headers: ${e.response?.headers}');

      // Try to extract more detailed error information
      String errorMessage = _extractErrorMessage(e);

      return ApiResponse(
        statusCode: e.response?.statusCode ?? 500,
        message: errorMessage,
        data: e.response?.data,
      );
    } catch (e) {
      print('DEBUG: General exception in addUserInterest: ${e.toString()}');
      return ApiResponse(
        statusCode: 500,
        message: 'An unexpected error occurred: ${e.toString()}',
        data: null,
      );
    }
  }

  Future<ApiResponse> getUserInterests({
    required String accessToken,
  }) async {
    try {
      print('DEBUG: Getting user interests');

      final response = await _dioConsumer.get(
        EndPoint.getUserInterests,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('DEBUG: Get user interests response: $response');
      print('DEBUG: Response type: ${response.runtimeType}');

      // Handle the case where response might be a List instead of Map
      if (response is List) {
        print('DEBUG: User interests response is a List');

        // Filter out invalid interests here too
        final validInterests = response.where((item) {
          if (item is Map<String, dynamic>) {
            final name = item['name'];
            final id = item['id'];

            return name != null &&
                name.toString().trim().isNotEmpty &&
                id != null;
          }
          return false;
        }).toList();

        return ApiResponse(
          statusCode: 200,
          message: 'Success',
          data: validInterests,
        );
      } else if (response is Map<String, dynamic>) {
        print('DEBUG: User interests response is a Map');

        // Check if the map has a data field that contains the interests
        if (response.containsKey('data') && response['data'] is List) {
          final List<dynamic> interestsList = response['data'];
          final validInterests = interestsList.where((item) {
            if (item is Map<String, dynamic>) {
              final name = item['name'];
              final id = item['id'];

              return name != null &&
                  name.toString().trim().isNotEmpty &&
                  id != null;
            }
            return false;
          }).toList();

          return ApiResponse(
            statusCode: 200,
            message: 'Success',
            data: validInterests,
          );
        }

        return ApiResponse.fromJson(response, (data) => data);
      } else {
        print('DEBUG: Unexpected response type: ${response.runtimeType}');
        return ApiResponse(
          statusCode: 200,
          message: 'Success',
          data: response,
        );
      }
    } on DioException catch (e) {
      print('DEBUG: DioException in getUserInterests: ${e.toString()}');
      print('DEBUG: Response data: ${e.response?.data}');
      print('DEBUG: Status code: ${e.response?.statusCode}');

      return ApiResponse(
        statusCode: e.response?.statusCode ?? 500,
        message: _extractErrorMessage(e),
        data: null,
      );
    } catch (e) {
      print('DEBUG: General exception in getUserInterests: ${e.toString()}');
      return ApiResponse(
        statusCode: 500,
        message: 'An unexpected error occurred: ${e.toString()}',
        data: null,
      );
    }
  }

  String _extractErrorMessage(DioException e) {
    if (e.response?.data != null) {
      final responseData = e.response!.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('message')) {
          return responseData['message'].toString();
        }
        if (responseData.containsKey('error')) {
          return responseData['error'].toString();
        }
        if (responseData.containsKey('errors')) {
          return responseData['errors'].toString();
        }
      }

      if (responseData is String) {
        return responseData;
      }
    }

    switch (e.response?.statusCode) {
      case 400:
        return 'Bad request - Invalid data provided';
      case 401:
        return 'Unauthorized - Please login again';
      case 403:
        return 'Forbidden - You don\'t have permission to perform this action';
      case 404:
        return 'Not found - The requested resource was not found';
      case 500:
        return 'Internal server error - Please try again later';
      default:
        return e.message ?? 'An unexpected error occurred';
    }
  }
}
