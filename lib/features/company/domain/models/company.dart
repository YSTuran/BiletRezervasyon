import '../../../../models/enums.dart';

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.officerUserId,
    required this.transportType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedByAdminId,
    this.reviewedAt,
    this.rejectionReason,
  });

  final String id;
  final String name;
  final String officerUserId;
  final TransportType transportType;
  final ApprovalStatus status;
  final String? reviewedByAdminId;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isApproved => status == ApprovalStatus.approved;

  Company copyWith({
    String? id,
    String? name,
    String? officerUserId,
    TransportType? transportType,
    ApprovalStatus? status,
    String? reviewedByAdminId,
    DateTime? reviewedAt,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      officerUserId: officerUserId ?? this.officerUserId,
      transportType: transportType ?? this.transportType,
      status: status ?? this.status,
      reviewedByAdminId: reviewedByAdminId ?? this.reviewedByAdminId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'officer_user_id': officerUserId,
      'transport_type': transportType.value,
      'status': status.value,
      'reviewed_by_admin_id': reviewedByAdminId,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      officerUserId: json['officer_user_id'] as String,
      transportType: TransportType.fromValue(json['transport_type'] as String),
      status: ApprovalStatus.fromValue(json['status'] as String),
      reviewedByAdminId: json['reviewed_by_admin_id'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
