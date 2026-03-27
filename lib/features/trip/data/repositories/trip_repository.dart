import '../../../../models/enums.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_seat.dart';

class TripRepository {
  TripRepository() {
    final reference = DateTime.now();
    _trips = _buildSeedTrips(reference);
    _tripSeats = _buildSeedSeats(_trips);
  }

  static const _demoCompanyId = 'company-demo';
  static const _demoOfficerId = 'officer-demo';

  late final List<Trip> _trips;
  late final List<TripSeat> _tripSeats;

  Future<List<Trip>> fetchTrips({required UserRole role}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final now = DateTime.now();
    final filteredTrips = switch (role) {
      UserRole.normalUser =>
        _trips
            .where(
              (trip) =>
                  trip.status == TripStatus.approved &&
                  trip.departureAt.isAfter(now),
            )
            .toList(),
      UserRole.companyOfficer =>
        _trips.where((trip) => trip.companyId == _demoCompanyId).toList(),
      UserRole.admin => List<Trip>.from(_trips),
    };

    filteredTrips.sort((a, b) => a.departureAt.compareTo(b.departureAt));
    return filteredTrips;
  }

  Future<Trip?> fetchTripById(String tripId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    for (final trip in _trips) {
      if (trip.id == tripId) {
        return trip;
      }
    }
    return null;
  }

  Future<List<TripSeat>> fetchTripSeats({required String tripId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final seats = _tripSeats.where((seat) => seat.tripId == tripId).toList();
    seats.sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
    return seats;
  }

  Future<Trip> createTrip({
    required TransportType transportType,
    required String origin,
    required String destination,
    required DateTime departureAt,
    required DateTime arrivalAt,
    required int seatCapacity,
    required int priceMinor,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final now = DateTime.now();
    final tripId = 'trip-${now.microsecondsSinceEpoch}';
    final trip = Trip(
      id: tripId,
      companyId: _demoCompanyId,
      createdByOfficerId: _demoOfficerId,
      transportType: transportType,
      tripCode: _generateTripCode(transportType, departureAt),
      origin: origin.trim(),
      destination: destination.trim(),
      departureAt: departureAt,
      arrivalAt: arrivalAt,
      seatCapacity: seatCapacity,
      priceMinor: priceMinor,
      status: TripStatus.pendingApproval,
      createdAt: now,
      updatedAt: now,
    );

    _trips.add(trip);
    _tripSeats.addAll(_buildSeatsForTrip(trip));
    return trip;
  }

  List<Trip> _buildSeedTrips(DateTime reference) {
    final trips = <Trip>[
      Trip(
        id: 'trip-001',
        companyId: _demoCompanyId,
        createdByOfficerId: _demoOfficerId,
        transportType: TransportType.bus,
        tripCode: 'BUS-IST-ANK',
        origin: 'Istanbul',
        destination: 'Ankara',
        departureAt: reference.add(const Duration(days: 1, hours: 3)),
        arrivalAt: reference.add(const Duration(days: 1, hours: 9)),
        seatCapacity: 32,
        priceMinor: 85000,
        status: TripStatus.approved,
        createdAt: reference.subtract(const Duration(days: 3)),
        updatedAt: reference.subtract(const Duration(hours: 12)),
      ),
      Trip(
        id: 'trip-002',
        companyId: _demoCompanyId,
        createdByOfficerId: _demoOfficerId,
        transportType: TransportType.flight,
        tripCode: 'FLT-IST-IZM',
        origin: 'Istanbul',
        destination: 'Izmir',
        departureAt: reference.add(const Duration(days: 2, hours: 2)),
        arrivalAt: reference.add(
          const Duration(days: 2, hours: 3, minutes: 10),
        ),
        seatCapacity: 18,
        priceMinor: 145000,
        status: TripStatus.pendingApproval,
        createdAt: reference.subtract(const Duration(days: 2)),
        updatedAt: reference.subtract(const Duration(hours: 6)),
      ),
      Trip(
        id: 'trip-003',
        companyId: 'company-other',
        createdByOfficerId: 'officer-other',
        transportType: TransportType.bus,
        tripCode: 'BUS-ANK-ADA',
        origin: 'Ankara',
        destination: 'Adana',
        departureAt: reference.add(const Duration(days: 3, hours: 1)),
        arrivalAt: reference.add(const Duration(days: 3, hours: 7)),
        seatCapacity: 40,
        priceMinor: 99000,
        status: TripStatus.approved,
        createdAt: reference.subtract(const Duration(days: 4)),
        updatedAt: reference.subtract(const Duration(days: 1)),
      ),
      Trip(
        id: 'trip-004',
        companyId: 'company-other',
        createdByOfficerId: 'officer-other',
        transportType: TransportType.flight,
        tripCode: 'FLT-AYT-IST',
        origin: 'Antalya',
        destination: 'Istanbul',
        departureAt: reference.add(const Duration(days: 4, hours: 5)),
        arrivalAt: reference.add(
          const Duration(days: 4, hours: 6, minutes: 20),
        ),
        seatCapacity: 24,
        priceMinor: 165000,
        status: TripStatus.rejected,
        createdAt: reference.subtract(const Duration(days: 5)),
        updatedAt: reference.subtract(const Duration(days: 2)),
        rejectionReason: 'Saat bilgisi eksik girildi.',
      ),
    ];

    trips.sort((a, b) => a.departureAt.compareTo(b.departureAt));
    return trips;
  }

  List<TripSeat> _buildSeedSeats(List<Trip> trips) {
    final allSeats = <TripSeat>[];
    for (final trip in trips) {
      allSeats.addAll(_buildSeatsForTrip(trip));
    }
    return allSeats;
  }

  List<TripSeat> _buildSeatsForTrip(Trip trip) {
    return List.generate(trip.seatCapacity, (index) {
      final seatNumber = '${index + 1}'.padLeft(2, '0');
      return TripSeat(
        id: '${trip.id}-seat-$seatNumber',
        tripId: trip.id,
        seatNumber: seatNumber,
        createdAt: trip.createdAt,
      );
    });
  }

  String _generateTripCode(TransportType transportType, DateTime departureAt) {
    final prefix = switch (transportType) {
      TransportType.bus => 'BUS',
      TransportType.flight => 'FLT',
    };
    final month = '${departureAt.month}'.padLeft(2, '0');
    final day = '${departureAt.day}'.padLeft(2, '0');
    final serial = (_trips.length + 1).toString().padLeft(2, '0');
    return '$prefix-$month$day-$serial';
  }
}
