import 'package:e_learning_app/core/model/match_response.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'package:dio/dio.dart';
import 'package:e_learning_app/core/service/auth_service.dart';

class MatchingService {
  final DioConsumer dioConsumer;
  final AuthService authService;

  MatchingService({
    required this.dioConsumer,
    required this.authService,
  });

  Future<MatchResponse?> findMatch(String matchType) async {
    try {
      final isAuthenticated =
          await authService.validateAndRefreshTokenIfNeeded();
      if (!isAuthenticated) {
        throw Exception('Authentication required');
      }

      final accessToken = await authService.getAccessToken();
      final currentUser = await authService.getCurrentUser();

      if (accessToken == null || currentUser == null) {
        throw Exception('No valid authentication found');
      }

      final response = await dioConsumer.post(
        EndPoint.findMatch,
        data: {
          'userId': currentUser.userId,
          'matchType': matchType,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response != null) {
        return MatchResponse.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error finding match: $e');

      if (e.toString().contains('404')) {
        return null; // No match found
      } else if (e.toString().contains('401') || e.toString().contains('403')) {
        final refreshed = await authService.forceTokenRefresh();
        if (refreshed) {
          return await findMatch(matchType);
        }
        throw Exception('Authentication failed');
      }

      throw Exception('Failed to find match: $e');
    }
  }

  Future<List<MatchResponse>> getMatches() async {
    try {
      final isAuthenticated =
          await authService.validateAndRefreshTokenIfNeeded();
      if (!isAuthenticated) {
        throw Exception('Authentication required');
      }

      final accessToken = await authService.getAccessToken();
      if (accessToken == null) {
        throw Exception('No valid access token found');
      }

      final response = await dioConsumer.get(
        EndPoint.getMatches,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response != null && response is List) {
        return response.map((json) => MatchResponse.fromJson(json)).toList();
      } else if (response != null &&
          response is Map &&
          response['data'] is List) {
        final List<dynamic> data = response['data'];
        return data.map((json) => MatchResponse.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting matches: $e');

      // Handle authentication errors
      if (e.toString().contains('401') || e.toString().contains('403')) {
        final refreshed = await authService.forceTokenRefresh();
        if (refreshed) {
          return await getMatches();
        }
        throw Exception('Authentication failed');
      }

      throw Exception('Failed to get matches: $e');
    }
  }

  Future<bool> endMatch(int matchId) async {
    try {
      final isAuthenticated =
          await authService.validateAndRefreshTokenIfNeeded();
      if (!isAuthenticated) {
        throw Exception('Authentication required');
      }

      final accessToken = await authService.getAccessToken();
      if (accessToken == null) {
        throw Exception('No valid access token found');
      }

      final response = await dioConsumer.put(
        '${EndPoint.endMatch}/$matchId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response != null && response is Map) {
        return response['statusCode'] == 200 || response['statusCode'] == 204;
      }

      return true;
    } catch (e) {
      print('Error ending match: $e');

      // Handle authentication errors
      if (e.toString().contains('401') || e.toString().contains('403')) {
        final refreshed = await authService.forceTokenRefresh();
        if (refreshed) {
          return await endMatch(matchId);
        }
        throw Exception('Authentication failed');
      }

      return false;
    }
  }
}
