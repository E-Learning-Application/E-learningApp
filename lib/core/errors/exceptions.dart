import 'package:dio/dio.dart';
import 'package:e_learning_app/core/errors/error_model.dart';

class ServerException implements Exception {
  final ErrorModel errModel;

  ServerException({required this.errModel});
}

void handleDioExceptions(DioException e) {
  print(
      'DEBUG: Handling DioException - Type: ${e.type}, Status: ${e.response?.statusCode}');
  print('DEBUG: Response data: ${e.response?.data}');
  print('DEBUG: Error message: ${e.message}');

  // Handle cases where response data might be null or not JSON
  Map<String, dynamic> errorData = {};
  if (e.response?.data != null) {
    if (e.response!.data is Map<String, dynamic>) {
      errorData = e.response!.data;
    } else if (e.response!.data is String) {
      // Handle string responses like "2"
      errorData = {
        'statusCode': e.response?.statusCode ?? 500,
        'message': 'Server error: ${e.response!.data}',
      };
    } else {
      errorData = {
        'statusCode': e.response?.statusCode ?? 500,
        'message': e.response?.data?.toString() ?? 'Unknown error',
      };
    }
  } else {
    errorData = {
      'statusCode': e.response?.statusCode ?? 500,
      'message': e.message ?? 'Unknown error occurred',
    };
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
      throw ServerException(errModel: ErrorModel.fromJson(errorData));
    case DioExceptionType.sendTimeout:
      throw ServerException(errModel: ErrorModel.fromJson(errorData));
    case DioExceptionType.receiveTimeout:
      throw ServerException(errModel: ErrorModel.fromJson(errorData));
    case DioExceptionType.badCertificate:
      throw ServerException(errModel: ErrorModel.fromJson(errorData));
    case DioExceptionType.cancel:
      throw ServerException(errModel: ErrorModel.fromJson(errorData));
    case DioExceptionType.connectionError:
      throw ServerException(errModel: ErrorModel.fromJson(errorData));
    case DioExceptionType.unknown:
      throw ServerException(errModel: ErrorModel.fromJson(errorData));
    case DioExceptionType.badResponse:
      switch (e.response?.statusCode) {
        case 400: // Bad request
          throw ServerException(errModel: ErrorModel.fromJson(errorData));
        case 401: //unauthorized
          throw ServerException(errModel: ErrorModel.fromJson(errorData));
        case 403: //forbidden
          throw ServerException(errModel: ErrorModel.fromJson(errorData));
        case 404: //not found
          throw ServerException(errModel: ErrorModel.fromJson(errorData));
        case 409: //coefficient
          throw ServerException(errModel: ErrorModel.fromJson(errorData));
        case 422: //  Unprocessable Entity
          throw ServerException(errModel: ErrorModel.fromJson(errorData));
        case 500: // Internal Server Error
          print('DEBUG: 500 error - Response data: ${e.response?.data}');
          throw ServerException(errModel: ErrorModel.fromJson(errorData));
        case 504: // Server exception
          throw ServerException(errModel: ErrorModel.fromJson(errorData));
        default:
          // Handle any other status codes
          print('DEBUG: Unhandled status code: ${e.response?.statusCode}');
          throw ServerException(errModel: ErrorModel.fromJson(errorData));
      }
  }
}
