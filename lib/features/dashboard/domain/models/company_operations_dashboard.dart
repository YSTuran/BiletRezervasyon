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
      stats: CompanyOperationsStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? const {},
      ),
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
      overallOccupancyRatePercent:
          json['overall_occupancy_rate_percent'] as int? ?? 0,
      upcomingTripCount: json['upcoming_trip_count'] as int? ?? 0,
      activeTripCount: json['active_trip_count'] as int? ?? 0,
      passengerCount: json['passenger_count'] as int? ?? 0,
      pendingReservationCount: json['pending_reservation_count'] as int? ?? 0,
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
      tripId: json['trip_id'] as String,
      tripCode: json['trip_code'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      departureAt: DateTime.parse(json['departure_at'] as String),
      arrivalAt: DateTime.parse(json['arrival_at'] as String),
      seatCapacity: json['seat_capacity'] as int? ?? 0,
      status: TripStatus.fromValue(json['status'] as String),
      transportType: TransportType.fromValue(json['transport_type'] as String),
      occupiedSeatCount: json['occupied_seat_count'] as int? ?? 0,
      paidPassengerCount: json['paid_passenger_count'] as int? ?? 0,
      occupancyRatePercent: json['occupancy_rate_percent'] as int? ?? 0,
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
      reservationId: json['reservation_id'] as String,
      tripId: json['trip_id'] as String,
      tripCode: json['trip_code'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      departureAt: DateTime.parse(json['departure_at'] as String),
      seatNumber: json['seat_number'] as String,
      passengerName: json['passenger_name'] as String,
      passengerEmail: json['passenger_email'] as String,
      reservationStatus: ReservationStatus.fromValue(
        json['reservation_status'] as String,
      ),
    );
  }
}
