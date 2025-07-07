import 'package:equatable/equatable.dart';

class InterestUpdateRequest extends Equatable {
  final String name;
  final String? description;

  const InterestUpdateRequest({
    required this.name,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
    };
  }

  @override
  List<Object?> get props => [name, description];
}
