import 'app_role.dart';

class AppUser {
  final String userId;
  String name;
  String email;
  AppRole role;
  String? hospitalId;
  bool active;
  String department;
  String createdBy;
  DateTime createdAt;

  AppUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.hospitalId,
    this.active = true,
    this.department = '',
    this.createdBy = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get requiresHospital => role != AppRole.superAdmin;

  Map<String, dynamic> toFirestoreMap() {
    return {
      'userId': userId,
      'nome': name,
      'email': email,
      'role': role.id,
      'hospitalId': hospitalId,
      'ativo': active,
      'departamento': department,
      'criadoPor': createdBy,
      'dataCriacao': createdAt.toIso8601String(),
    };
  }
}
