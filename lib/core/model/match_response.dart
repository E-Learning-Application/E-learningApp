import 'package:e_learning_app/core/model/user_dto.dart';

class MatchResponse {
  final int id;
  final UserDto matchedUser;
  final String matchType;
  final DateTime createdAt;
  final bool isActive;
  final double matchScore;

  MatchResponse({
    required this.id,
    required this.matchedUser,
    required this.matchType,
    required this.createdAt,
    required this.isActive,
    required this.matchScore,
  });

  factory MatchResponse.fromJson(Map<String, dynamic> json, int currentUserId) {
    final isCurrentUser1 = json['userId1'] == currentUserId;
    return MatchResponse(
      id: json['id'],
      matchedUser: isCurrentUser1
          ? UserDto(
              id: json['userId2'],
              username: json['userName2'],
              profilePicture: json['imagePath2'],
              languages: null,
            )
          : UserDto(
              id: json['userId1'],
              username: json['userName1'],
              profilePicture: json['imagePath1'],
              languages: null,
            ),
      matchType: json['matchType'],
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'],
      matchScore: (json['matchScore'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'matchedUser': matchedUser.toJson(),
      'matchType': matchType,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'matchScore': matchScore,
    };
  }
}
