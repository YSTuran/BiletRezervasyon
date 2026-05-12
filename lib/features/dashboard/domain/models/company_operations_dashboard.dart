import '../../../../models/enums.dart';
import '../../../company/domain/models/company.dart';

class CompanyOperationsDashboard {
  const CompanyOperationsDashboard({
    required this.stats,
    required this.upcomingTrips,
    required this.passengerManifest,
    this.company,
  });

  final Company? company;
  final CompanyOperationsStats stats;
  final List<CompanyOperationsTripSnapshot> upcomingTrips;
  final List<PassengerManifestEntry> passengerManifest;

  factory CompanyOperationsDashboard.fromJson(Map<String, dynamic> json) {
    final companyJson = json['company'];
    return CompanyOperationsDashboard(
      company: companyJson is Map<String, dynamic>
          ? Company.fromJson(companyJson)
          : null,
      stats: CompanyOperationsStats.fromJson(_readMap(json['stats'])),
      upcomingTrips: (json['upcoming_trips'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CompanyOperationsTripSnapshot.fromJson)
          .toList(),
      passengerManifest:
          (json['passenger_manifest'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(PassengerManifestEntry.fromJson)
              .toList(),
    );
  }
}

class CompanyOperationsStats {
  const CompanyOperationsStats({
    required this.overallOccupancyRatePercent,
    required this.upcomingTripCount,
    required this.activeTripCount,
    required this.passengerCount,
    required this.pendingReservationCount,
  });

  final int overallOccupancyRatePercent;
  final int upcomingTripCount;
  final int activeTripCount;
  final int passengerCount;
  final int pendingReservationCount;

  factory CompanyOperationsStats.fromJson(Map<String, dynamic> json) {
    return CompanyOperationsStats(
      overallOccupancyRatePercent: _readInt(
        json['overall_occupancy_rate_percent'],
      ),
      upcomingTripCount: _readInt(json['upcoming_trip_count']),
      activeTripCount: _readInt(json['active_trip_count']),
      passengerCount: _readInt(json['passenger_count']),
      pendingReservationCount: _readInt(json['pending_reservation_count']),
    );
  }
}

class CompanyOperationsTripSnapshot {
  const CompanyOperationsTripSnapshot({
    required this.tripId,
    required this.tripCode,
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.arrivalAt,
    required this.seatCapacity,
    required this.status,
    required this.transportType,
    required this.occupiedSeatCount,
    required this.paidPassengerCount,
    required this.occupancyRatePercent,
  });

  final String tripId;
  final String tripCode;
  final String origin;
  final String destination;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final int seatCapacity;
  final TripStatus status;
  final TransportType transportType;
  final int occupiedSeatCount;
  final int paidPassengerCount;
  final int occupancyRatePercent;

  factory CompanyOperationsTripSnapshot.fromJson(Map<String, dynamic> json) {
    return CompanyOperationsTripSnapshot(
      tripId: _readString(json['trip_id']),
      tripCode: _readString(json['trip_code'], fallback: '-'),
      origin: _readString(json['origin'], fallback: '-'),
      destination: _readString(json['destination'], fallback: '-'),
      departureAt: _readDate(json['departure_at']),
      arrivalAt: _readDate(json['arrival_at']),
      seatCapacity: _readInt(json['seat_capacity']),
      status: _readTripStatus(json['status']),
      transportType: _readTransportType(json['transport_type']),
      occupiedSeatCount: _readInt(json['occupied_seat_count']),
      paidPassengerCount: _readInt(json['paid_passenger_count']),
      occupancyRatePercent: _readInt(json['occupancy_rate_percent']),
    );
  }
}

class PassengerManifestEntry {
  const PassengerManifestEntry({
    required this.reservationId,
    required this.tripId,
    required this.tripCode,
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.seatNumber,
    required this.passengerName,
    required this.passengerEmail,
    required this.reservationStatus,
  });

  final String reservationId;
  final String tripId;
  final String tripCode;
  final String origin;
  final String destination;
  final DateTime departureAt;
  final String seatNumber;
  final String passengerName;
  final String passengerEmail;
  final ReservationStatus reservationStatus;

  factory PassengerManifestEntry.fromJson(Map<String, dynamic> json) {
    return PassengerManifestEntry(
      reservationId: _readString(json['reservation_id']),
      tripId: _readString(json['trip_id']),
      tripCode: _readString(json['trip_code'], fallback: '-'),
      origin: _readString(json['origin'], fallback: '-'),
      destination: _readString(json['destination'], fallback: '-'),
      departureAt: _readDate(json['departure_at']),
      seatNumber: _readString(json['seat_number'], fallback: '-'),
      passengerName: _readString(json['passenger_name'], fallback: '-'),
      passengerEmail: _readString(json['passenger_email'], fallback: '-'),
      reservationStatus: _readReservationStatus(json['reservation_status']),
    );
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, data) => MapEntry('$key', data));
  }
  return const {};
}

String _readString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

DateTime _readDate(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  final text = value?.toString().trim() ?? '';
  return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

TripStatus _readTripStatus(dynamic value) {
  try {
    return TripStatus.fromValue(_readString(value));
  } catch (_) {
    return TripStatus.approved;
  }
}

TransportType _readTransportType(dynamic value) {
  try {
    return TransportType.fromValue(_readString(value));
  } catch (_) {
    return TransportType.bus;
  }
}

ReservationStatus _readReservationStatus(dynamic value) {
  try {
    return ReservationStatus.fromValue(_readString(value));
  } catch (_) {
    return ReservationStatus.approved;
  }
}
