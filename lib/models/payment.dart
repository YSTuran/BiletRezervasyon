import 'enums.dart';

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
    );
  }
}
