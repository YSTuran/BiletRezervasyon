class TripSeat {
  const TripSeat({
    required this.id,
    required this.tripId,
    required this.seatNumber,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String seatNumber;
  final DateTime createdAt;

  TripSeat copyWith({
    String? id,
    String? tripId,
    String? seatNumber,
    DateTime? createdAt,
  }) {
    return TripSeat(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      seatNumber: seatNumber ?? this.seatNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'seat_number': seatNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TripSeat.fromJson(Map<String, dynamic> json) {
    return TripSeat(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      seatNumber: json['seat_number'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
