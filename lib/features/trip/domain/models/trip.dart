import '../../../../models/enums.dart';

class Trip {
  Trip({
    required this.id,
    required this.companyId,
    required this.createdByOfficerId,
    required this.transportType,
    required this.tripCode,
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.arrivalAt,
    required this.seatCapacity,
    required this.priceMinor,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedByAdminId,
    this.reviewedAt,
    this.rejectionReason,
  }) : assert(seatCapacity > 0, 'seatCapacity must be greater than 0'),
       assert(priceMinor >= 0, 'priceMinor cannot be negative') {
    assert(
      departureAt.isBefore(arrivalAt),
      'departureAt must be before arrivalAt',
    );
  }

  final String id;
  final String companyId;
  final String createdByOfficerId;
  final TransportType transportType;
  final String tripCode;
  final String origin;
  final String destination;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final int seatCapacity;
  final int priceMinor;
  final TripStatus status;
  final String? reviewedByAdminId;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isApproved => status == TripStatus.approved;

  Trip copyWith({
    String? id,
    String? companyId,
    String? createdByOfficerId,
    TransportType? transportType,
    String? tripCode,
    String? origin,
    String? destination,
    DateTime? departureAt,
    DateTime? arrivalAt,
    int? seatCapacity,
    int? priceMinor,
    TripStatus? status,
    String? reviewedByAdminId,
    DateTime? reviewedAt,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      createdByOfficerId: createdByOfficerId ?? this.createdByOfficerId,
      transportType: transportType ?? this.transportType,
      tripCode: tripCode ?? this.tripCode,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      departureAt: departureAt ?? this.departureAt,
      arrivalAt: arrivalAt ?? this.arrivalAt,
      seatCapacity: seatCapacity ?? this.seatCapacity,
      priceMinor: priceMinor ?? this.priceMinor,
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
      'company_id': companyId,
      'created_by_officer_id': createdByOfficerId,
      'transport_type': transportType.value,
      'trip_code': tripCode,
      'origin': origin,
      'destination': destination,
      'departure_at': departureAt.toIso8601String(),
      'arrival_at': arrivalAt.toIso8601String(),
      'seat_capacity': seatCapacity,
      'price_minor': priceMinor,
      'status': status.value,
      'reviewed_by_admin_id': reviewedByAdminId,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      createdByOfficerId: json['created_by_officer_id'] as String,
      transportType: TransportType.fromValue(json['transport_type'] as String),
      tripCode: json['trip_code'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      departureAt: DateTime.parse(json['departure_at'] as String),
      arrivalAt: DateTime.parse(json['arrival_at'] as String),
      seatCapacity: json['seat_capacity'] as int,
      priceMinor: json['price_minor'] as int,
      status: TripStatus.fromValue(json['status'] as String),
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
