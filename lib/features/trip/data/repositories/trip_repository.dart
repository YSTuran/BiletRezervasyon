import '../../../../models/enums.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../company/data/repositories/company_repository.dart';
import '../../../company/domain/models/company.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_seat.dart';

class TripRepository {
  TripRepository({
    required CompanyRepository companyRepository,
    required AuthRepository authRepository,
  }) : _companyRepository = companyRepository,
       _authRepository = authRepository;

  final CompanyRepository _companyRepository;
  final AuthRepository _authRepository;
  final List<Trip> _trips = [];
  final List<TripSeat> _tripSeats = [];

  Company? get currentOfficerCompany =>
      _companyRepository.currentOfficerCompany;

  TransportType? get currentOfficerTransportType =>
      currentOfficerCompany?.transportType;

  bool get canCurrentOfficerCreateTrips =>
      currentOfficerCompany?.status == ApprovalStatus.approved;

  String? get currentOfficerTripCreationBlockMessage {
    final company = currentOfficerCompany;
    if (company == null) {
      return 'Sefer olusturmak icin once firma bilgilerinizi doldurmalisiniz.';
    }

    return switch (company.status) {
      ApprovalStatus.pending =>
        'Firma bilgileriniz admin onayi bekledigi icin henuz sefer olusturamazsiniz.',
      ApprovalStatus.rejected =>
        'Firma bilgileriniz reddedildigi icin once duzenleyip tekrar gondermelisiniz.',
      ApprovalStatus.approved => null,
    };
  }

  Future<List<Trip>> fetchTrips({required UserRole role}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final filteredTrips = switch (role) {
      UserRole.normalUser =>
        _trips.where((trip) => trip.status == TripStatus.approved).toList(),
      UserRole.companyOfficer =>
        currentOfficerCompany == null
            ? <Trip>[]
            : _trips
                  .where((trip) => trip.companyId == currentOfficerCompany!.id)
                  .toList(),
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

    final company = currentOfficerCompany;
    if (company == null) {
      throw StateError('Firma bilgisi bulunamadigi icin sefer olusturulamadi.');
    }
    if (company.status != ApprovalStatus.approved) {
      throw StateError('Firma bilgileri onaylanmadan sefer olusturulamaz.');
    }
    if (transportType != company.transportType) {
      throw StateError('Firma sadece tek bir ulasim tipi icin sefer acabilir.');
    }

    final now = DateTime.now();
    final tripId = 'trip-${now.microsecondsSinceEpoch}';
    final trip = Trip(
      id: tripId,
      companyId: company.id,
      createdByOfficerId: company.officerUserId,
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

  Future<Trip?> approveTrip({required String tripId}) async {
    return _reviewTrip(tripId: tripId, status: TripStatus.approved);
  }

  Future<Trip?> rejectTrip({
    required String tripId,
    required String rejectionReason,
  }) async {
    return _reviewTrip(
      tripId: tripId,
      status: TripStatus.rejected,
      rejectionReason: rejectionReason,
    );
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

  Future<Trip?> _reviewTrip({
    required String tripId,
    required TripStatus status,
    String? rejectionReason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final index = _trips.indexWhere((trip) => trip.id == tripId);
    if (index < 0) {
      return null;
    }

    final currentTrip = _trips[index];
    final now = DateTime.now();
    final reviewerId = _authRepository.resolveCurrentUserId();
    if (reviewerId == null || reviewerId.isEmpty) {
      throw StateError(
        'Aktif kullanici bulunamadigi icin islem tamamlanamadi.',
      );
    }
    final updatedTrip = currentTrip.copyWith(
      status: status,
      reviewedByAdminId: reviewerId,
      reviewedAt: now,
      rejectionReason: status == TripStatus.rejected
          ? rejectionReason?.trim()
          : null,
      updatedAt: now,
    );

    _trips[index] = updatedTrip;
    return updatedTrip;
  }
}
