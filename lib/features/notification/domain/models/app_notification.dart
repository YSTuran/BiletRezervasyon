class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.relatedTripId,
    this.relatedReservationId,
    this.relatedPaymentId,
    this.readAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String category;
  final String? relatedTripId;
  final String? relatedReservationId;
  final String? relatedPaymentId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      body: body,
      category: category,
      relatedTripId: relatedTripId,
      relatedReservationId: relatedReservationId,
      relatedPaymentId: relatedPaymentId,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      category: json['category'] as String,
      relatedTripId: json['related_trip_id'] as String?,
      relatedReservationId: json['related_reservation_id'] as String?,
      relatedPaymentId: json['related_payment_id'] as String?,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
