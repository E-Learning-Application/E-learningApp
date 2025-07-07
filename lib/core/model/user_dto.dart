class UserDto {
  final int id;
  final String username;
  final String? profilePicture;
  final List<String>? languages;

  UserDto({
    required this.id,
    required this.username,
    this.profilePicture,
    this.languages,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'],
      username: json['username'],
      profilePicture: json['profilePicture'],
      languages: json['languages']?.cast<String>(),
    );
  }
}
