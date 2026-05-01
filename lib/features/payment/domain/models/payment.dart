import '../../../../models/enums.dart';

class Payment {
  const Payment({
    required this.id,
    required this.reservationId,
    required this.amountMinor,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.provider,
    this.providerPaymentId,
    this.paidAt,
    this.reservationStatus,
    this.paymentDeadlineAt,
    this.seatNumber,
    this.tripCode,
    this.tripOrigin,
    this.tripDestination,
    this.tripDepartureAt,
    this.tripArrivalAt,
    this.tripTransportType,
    this.companyName,
  }) : assert(amountMinor > 0, 'amountMinor must be greater than 0');

  final String id;
  final String reservationId;
  final int amountMinor;
  final PaymentStatus status;
  final String? provider;
  final String? providerPaymentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? paidAt;
  final ReservationStatus? reservationStatus;
  final DateTime? paymentDeadlineAt;
  final String? seatNumber;
  final String? tripCode;
  final String? tripOrigin;
  final String? tripDestination;
  final DateTime? tripDepartureAt;
  final DateTime? tripArrivalAt;
  final TransportType? tripTransportType;
  final String? companyName;

  Payment copyWith({
    String? id,
    String? reservationId,
    int? amountMinor,
    PaymentStatus? status,
    String? provider,
    String? providerPaymentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidAt,
    ReservationStatus? reservationStatus,
    DateTime? paymentDeadlineAt,
    String? seatNumber,
    String? tripCode,
    String? tripOrigin,
    String? tripDestination,
    DateTime? tripDepartureAt,
    DateTime? tripArrivalAt,
    TransportType? tripTransportType,
    String? companyName,
  }) {
    return Payment(
      id: id ?? this.id,
      reservationId: reservationId ?? this.reservationId,
      amountMinor: amountMinor ?? this.amountMinor,
      status: status ?? this.status,
      provider: provider ?? this.provider,
      providerPaymentId: providerPaymentId ?? this.providerPaymentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
      reservationStatus: reservationStatus ?? this.reservationStatus,
      paymentDeadlineAt: paymentDeadlineAt ?? this.paymentDeadlineAt,
      seatNumber: seatNumber ?? this.seatNumber,
      tripCode: tripCode ?? this.tripCode,
      tripOrigin: tripOrigin ?? this.tripOrigin,
      tripDestination: tripDestination ?? this.tripDestination,
      tripDepartureAt: tripDepartureAt ?? this.tripDepartureAt,
      tripArrivalAt: tripArrivalAt ?? this.tripArrivalAt,
      tripTransportType: tripTransportType ?? this.tripTransportType,
      companyName: companyName ?? this.companyName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reservation_id': reservationId,
      'amount_minor': amountMinor,
      'status': status.value,
      'provider': provider,
      'provider_payment_id': providerPaymentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'reservation_status': reservationStatus?.value,
      'payment_deadline_at': paymentDeadlineAt?.toIso8601String(),
      'seat_number': seatNumber,
      'trip_code': tripCode,
      'trip_origin': tripOrigin,
      'trip_destination': tripDestination,
      'trip_departure_at': tripDepartureAt?.toIso8601String(),
      'trip_arrival_at': tripArrivalAt?.toIso8601String(),
      'trip_transport_type': tripTransportType?.value,
      'company_name': companyName,
    };
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      reservationId: json['reservation_id'] as String,
      amountMinor: json['amount_minor'] as int,
      status: PaymentStatus.fromValue(json['status'] as String),
      provider: json['provider'] as String?,
      providerPaymentId: json['provider_payment_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      paidAt: json['paid_at'] == null
          ? null
          : DateTime.parse(json['paid_at'] as String),
      reservationStatus: json['reservation_status'] == null
          ? null
          : ReservationStatus.fromValue(json['reservation_status'] as String),
      paymentDeadlineAt: json['payment_deadline_at'] == null
          ? null
          : DateTime.parse(json['payment_deadline_at'] as String),
      seatNumber: json['seat_number'] as String?,
      tripCode: json['trip_code'] as String?,
      tripOrigin: json['trip_origin'] as String?,
      tripDestination: json['trip_destination'] as String?,
      tripDepartureAt: json['trip_departure_at'] == null
          ? null
          : DateTime.parse(json['trip_departure_at'] as String),
      tripArrivalAt: json['trip_arrival_at'] == null
          ? null
          : DateTime.parse(json['trip_arrival_at'] as String),
      tripTransportType: json['trip_transport_type'] == null
          ? null
          : TransportType.fromValue(json['trip_transport_type'] as String),
      companyName: json['company_name'] as String?,
    );
  }
}
