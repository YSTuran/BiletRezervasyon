import 'enums.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.companyId,
  }) : assert(
         role == UserRole.companyOfficer || companyId == null,
         'Only company officers can have a companyId.',
       );

  final String id;
  final String firebaseUid;
  final String email;
  final String fullName;
  final UserRole role;
  final String? companyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser copyWith({
    String? id,
    String? firebaseUid,
    String? email,
    String? fullName,
    UserRole? role,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebase_uid': firebaseUid,
      'email': email,
      'full_name': fullName,
      'role': role.value,
      'company_id': companyId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      firebaseUid: json['firebase_uid'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: UserRole.fromValue(json['role'] as String),
      companyId: json['company_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
