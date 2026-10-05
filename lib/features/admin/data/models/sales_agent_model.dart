import 'package:equatable/equatable.dart';

/// Strongly-typed immutable SalesAgentModel
class SalesAgentModel extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String role;
  final bool isAvailableForCalls;
  final String? did;
  final String? vid;

  const SalesAgentModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    this.role = 'sales',
    this.isAvailableForCalls = true,
    this.did,
    this.vid,
  });

  String get fullName => '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName'.trim() : 'Sales Agent';

  factory SalesAgentModel.fromJson(Map<String, dynamic> json) {
    final config = json['myoperatorConfig'] is Map ? json['myoperatorConfig'] as Map : {};
    return SalesAgentModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? '').toString(),
      role: (json['role'] ?? 'sales').toString(),
      isAvailableForCalls: json['isAvailableForCalls'] != false,
      did: config['did']?.toString() ?? config['whatsappNumber']?.toString(),
      vid: config['vid']?.toString() ?? config['extension']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role,
      'isAvailableForCalls': isAvailableForCalls,
      'did': did,
      'vid': vid,
    };
  }

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        email,
        phoneNumber,
        role,
        isAvailableForCalls,
        did,
        vid,
      ];
}
