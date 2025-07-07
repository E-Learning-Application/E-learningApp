import 'package:e_learning_app/core/model/user_dto.dart';

class MatchResponse {
  final int id;
  final UserDto matchedUser;
  final String matchType;
  final DateTime createdAt;
  final bool isActive;

  MatchResponse({
    required this.id,
    required this.matchedUser,
    required this.matchType,
    required this.createdAt,
    required this.isActive,
  });

  factory MatchResponse.fromJson(Map<String, dynamic> json) {
    return MatchResponse(
      id: json['id'],
      matchedUser: UserDto.fromJson(json['matchedUser']),
      matchType: json['matchType'],
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'],
    );
  }
}
