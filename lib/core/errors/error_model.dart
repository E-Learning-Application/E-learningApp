import 'package:e_learning_app/core/api/end_points.dart';

class ErrorModel {
  final int status;
  final String errorMessage;

  ErrorModel({required this.status, required this.errorMessage});
  factory ErrorModel.fromJson(Map<String, dynamic> jsonData) {
    int statusCode;
    String message;

    try {
      final statusValue =
          jsonData[ApiKey.status] ?? jsonData['statusCode'] ?? 500;
      if (statusValue is String) {
        statusCode = int.tryParse(statusValue) ?? 500;
      } else if (statusValue is int) {
        statusCode = statusValue;
      } else {
        statusCode = 500;
      }
    } catch (e) {
      statusCode = 500;
    }

    try {
      final messageValue = jsonData[ApiKey.errorMessage] ??
          jsonData['message'] ??
          jsonData['error'] ??
          'Unknown error occurred';
      if (messageValue is String) {
        message = messageValue;
      } else {
        message = messageValue.toString();
      }
    } catch (e) {
      message = 'Unknown error occurred';
    }

    return ErrorModel(
      status: statusCode,
      errorMessage: message,
    );
  }
}
