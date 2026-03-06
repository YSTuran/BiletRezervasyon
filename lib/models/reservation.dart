import 'enums.dart';

class Reservation {
  const Reservation({
    required this.id,
    required this.tripId,
    required this.tripSeatId,
    required this.userId,
    required this.status,
    required this.requestedAt,
    required this.paymentDeadlineAt,
    this.decidedByOfficerId,
    this.decidedAt,
    this.rejectionReason,
    this.paidAt,
    this.cancelledAt,
  });

  final String id;
  final String tripId;
  final String tripSeatId;
  final String userId;
  final ReservationStatus status;
  final DateTime requestedAt;
  final DateTime paymentDeadlineAt;
  final String? decidedByOfficerId;
  final DateTime? decidedAt;
  final String? rejectionReason;
  final DateTime? paidAt;
  final DateTime? cancelledAt;

  bool get blocksSeat => status.blocksSeat;

  bool isPaymentLate(DateTime now) =>
      status == ReservationStatus.approved && now.isAfter(paymentDeadlineAt);

  Reservation copyWith({
    String? id,
    String? tripId,
    String? tripSeatId,
    String? userId,
    ReservationStatus? status,
    DateTime? requestedAt,
    DateTime? paymentDeadlineAt,
    String? decidedByOfficerId,
    DateTime? decidedAt,
    String? rejectionReason,
    DateTime? paidAt,
    DateTime? cancelledAt,
  }) {
    return Reservation(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      tripSeatId: tripSeatId ?? this.tripSeatId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      paymentDeadlineAt: paymentDeadlineAt ?? this.paymentDeadlineAt,
      decidedByOfficerId: decidedByOfficerId ?? this.decidedByOfficerId,
      decidedAt: decidedAt ?? this.decidedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      paidAt: paidAt ?? this.paidAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'trip_seat_id': tripSeatId,
      'user_id': userId,
      'status': status.value,
      'requested_at': requestedAt.toIso8601String(),
      'payment_deadline_at': paymentDeadlineAt.toIso8601String(),
      'decided_by_officer_id': decidedByOfficerId,
      'decided_at': decidedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'paid_at': paidAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
    };
  }

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      tripSeatId: json['trip_seat_id'] as String,
      userId: json['user_id'] as String,
      status: ReservationStatus.fromValue(json['status'] as String),
      requestedAt: DateTime.parse(json['requested_at'] as String),
      paymentDeadlineAt: DateTime.parse(json['payment_deadline_at'] as String),
      decidedByOfficerId: json['decided_by_officer_id'] as String?,
      decidedAt: json['decided_at'] == null
          ? null
          : DateTime.parse(json['decided_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      paidAt: json['paid_at'] == null
          ? null
          : DateTime.parse(json['paid_at'] as String),
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at'] as String),
    );
  }
}
