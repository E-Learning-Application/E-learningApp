class Language {
  final int id;
  final String name;
  final String code;
  final String? flag;

  Language({
    required this.id,
    required this.name,
    required this.code,
    this.flag,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      flag: json['flag'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'flag': flag,
    };
  }
}

class LanguagePreference {
  final Language language;
  final String proficiencyLevel;
  final bool isLearning;

  LanguagePreference({
    required this.language,
    required this.proficiencyLevel,
    required this.isLearning,
  });

  factory LanguagePreference.fromJson(Map<String, dynamic> json) {
    return LanguagePreference(
      language: Language.fromJson(json['language']),
      proficiencyLevel: json['proficiencyLevel'],
      isLearning: json['isLearning'],
    );
  }
}

enum LanguageProficiencyLevel {
  basic('Basic'),
  conversational('Conversational'),
  fluent('Fluent'),
  native('Native');

  const LanguageProficiencyLevel(this.value);
  final String value;
}
