import 'package:e_learning_app/core/model/match_response.dart';
import 'package:e_learning_app/core/api/dio_consumer.dart';
import 'package:e_learning_app/core/api/end_points.dart';
import 'package:dio/dio.dart';
import 'package:e_learning_app/core/service/auth_service.dart';
import 'dart:developer';

class MatchingService {
  final DioConsumer dioConsumer;
  final AuthService authService;

  MatchingService({
    required this.dioConsumer,
    required this.authService,
  });

  Future<MatchResponse?> findMatch(String matchType) async {
    try {
      log('Finding match via REST API for type: $matchType');

      final isAuthenticated =
          await authService.validateAndRefreshTokenIfNeeded();
      if (!isAuthenticated) {
        log('Authentication validation failed');
        throw Exception('Authentication required');
      }

      final accessToken = await authService.getAccessToken();
      final currentUser = await authService.getCurrentUser();

      log('Current user: ${currentUser?.userId}, Access token: ${accessToken != null ? 'Present' : 'Missing'}');

      if (accessToken == null || currentUser == null) {
        log('Missing authentication data - Access token: ${accessToken != null}, Current user: ${currentUser != null}');
        throw Exception('No valid authentication found');
      }

      final requestData = {
        'userId': currentUser.userId,
        'matchType': matchType,
      };

      log('Sending request data: $requestData');

      final response = await dioConsumer.post(
        EndPoint.findMatch,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      log('Raw response from server: $response');
      log('Response type: ${response.runtimeType}');

      if (response != null) {
        if (response is Map<String, dynamic>) {
          log('Match found via REST API: ${response.toString()}');
          return MatchResponse.fromJson(response);
        } else {
          log('Unexpected response type: ${response.runtimeType}');
          return null;
        }
      }

      log('No response received from server');
      return null;
    } catch (e) {
      log('Error finding match via REST API: $e');
      log('Error type: ${e.runtimeType}');

      // Log more details about DioException
      if (e.toString().contains('DioException')) {
        log('DioException details: $e');
      }

      if (e.toString().contains('404')) {
        log('No match found (404)');
        return null; // No match found
      } else if (e.toString().contains('401') || e.toString().contains('403')) {
        log('Authentication error, attempting token refresh');
        final refreshed = await authService.forceTokenRefresh();
        if (refreshed) {
          log('Token refreshed, retrying match request');
          return await findMatch(matchType);
        }
        throw Exception('Authentication failed');
      } else if (e.toString().contains('500')) {
        log('Server error (500) - this indicates a server-side exception');
        log('This usually means no compatible users are available for matching');
        return null; // Return null instead of throwing, so we can fall back to SignalR
      }

      throw Exception('Failed to find match: $e');
    }
  }

  Future<List<MatchResponse>> getMatches() async {
    try {
      log('Getting matches via REST API');

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
        log('Found ${response.length} matches');
        return response.map((json) => MatchResponse.fromJson(json)).toList();
      } else if (response != null &&
          response is Map &&
          response['data'] is List) {
        final List<dynamic> data = response['data'];
        log('Found ${data.length} matches in data field');
        return data.map((json) => MatchResponse.fromJson(json)).toList();
      }

      log('No matches found');
      return [];
    } catch (e) {
      log('Error getting matches: $e');

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

  Future<Map<String, dynamic>?> testServerConnection() async {
    try {
      log('Testing server connection...');

      final isAuthenticated =
          await authService.validateAndRefreshTokenIfNeeded();
      if (!isAuthenticated) {
        log('Authentication failed during connection test');
        return null;
      }

      final accessToken = await authService.getAccessToken();
      final currentUser = await authService.getCurrentUser();

      if (accessToken == null || currentUser == null) {
        log('Missing auth data during connection test');
        return null;
      }

      log('Testing GET /api/matching endpoint...');
      final response = await dioConsumer.get(
        EndPoint.getMatches,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      log('Connection test successful. Response: $response');
      return {
        'status': 'connected',
        'currentUser': currentUser.userId,
        'matches': response is List ? response.length : 0,
        'message':
            'Server is working, but you may need another user to test matching',
      };
    } catch (e) {
      log('Connection test failed: $e');
      return {
        'status': 'failed',
        'error': e.toString(),
      };
    }
  }

  Future<bool> endMatch(int matchId) async {
    try {
      log('Ending match via REST API: $matchId');

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
        final success =
            response['statusCode'] == 200 || response['statusCode'] == 204;
        log('Match ended successfully: $success');
        return success;
      }

      log('Match ended (no response body)');
      return true;
    } catch (e) {
      log('Error ending match: $e');

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
