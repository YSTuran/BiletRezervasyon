import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/data/services/postgres_callable_service.dart';
import '../../../../models/enums.dart';
import '../../../company/data/repositories/company_repository.dart';
import '../../../company/domain/models/company.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_seat.dart';

class TripRepository {
  TripRepository({required CompanyRepository companyRepository})
    : _companyRepository = companyRepository;

  final CompanyRepository _companyRepository;
  final Map<String, List<TripSeat>> _seatCache = <String, List<TripSeat>>{};

  Company? get currentOfficerCompany =>
      _companyRepository.currentOfficerCompany;

  TransportType? get currentOfficerTransportType =>
      currentOfficerCompany?.transportType;

  bool get canCurrentOfficerCreateTrips =>
      currentOfficerCompany?.status == ApprovalStatus.approved;

  String? get currentOfficerTripCreationBlockMessage {
    final company = currentOfficerCompany;
    if (company == null) {
      return 'Sefer oluşturmak için önce firma bilgilerinizi doldurmalısınız.';
    }

    return switch (company.status) {
      ApprovalStatus.pending =>
        'Firma bilgileriniz admin onayı beklediği için henüz sefer oluşturamazsınız.',
      ApprovalStatus.rejected =>
        'Firma bilgileriniz reddedildiği için önce düzenleyip tekrar göndermelisiniz.',
      ApprovalStatus.approved => null,
    };
  }

  Future<void> refreshCurrentOfficerCompany() async {
    await _companyRepository.fetchCurrentOfficerCompany();
  }

  Future<List<Trip>> fetchTrips({required UserRole role}) async {
    if (role == UserRole.companyOfficer) {
      await refreshCurrentOfficerCompany();
    }

    try {
      final response = await PostgresCallableService.call(
        functionName: 'listTrips',
      );
      return _parseTrips(response['trips']);
    } on FirebaseFunctionsException catch (error) {
      throw TripActionException(_mapTripError(error.code, error.message));
    }
  }

  Future<Trip?> fetchTripById(String tripId) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'getTripDetail',
        data: {'tripId': tripId},
      );

      final trip = _parseTrip(response['trip']);
      final seats = _parseSeats(response['seats']);
      if (trip == null) {
        _seatCache.remove(tripId);
      } else {
        _seatCache[tripId] = seats;
      }
      return trip;
    } on FirebaseFunctionsException catch (error) {
      throw TripActionException(_mapTripError(error.code, error.message));
    }
  }

  Future<List<TripSeat>> fetchTripSeats({required String tripId}) async {
    final cachedSeats = _seatCache[tripId];
    if (cachedSeats != null) {
      return cachedSeats;
    }

    await fetchTripById(tripId);
    return _seatCache[tripId] ?? const [];
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
    await refreshCurrentOfficerCompany();
    final company = currentOfficerCompany;
    if (company == null) {
      throw const TripActionException(
        'Firma bilgisi bulunamadığı için sefer oluşturulamadı.',
      );
    }
    if (company.status != ApprovalStatus.approved) {
      throw const TripActionException(
        'Firma bilgileri onaylanmadan sefer oluşturulamaz.',
      );
    }
    if (transportType != company.transportType) {
      throw const TripActionException(
        'Firma sadece tek bir ulaşım tipi için sefer açabilir.',
      );
    }

    try {
      final response = await PostgresCallableService.call(
        functionName: 'createTrip',
        data: {
          'transportType': transportType.value,
          'origin': origin.trim(),
          'destination': destination.trim(),
          'departureAt': departureAt.toIso8601String(),
          'arrivalAt': arrivalAt.toIso8601String(),
          'seatCapacity': seatCapacity,
          'priceMinor': priceMinor,
        },
      );

      final trip = _parseTrip(response['trip']);
      if (trip == null) {
        throw const TripActionException('Sefer oluşturulamadı.');
      }

      _seatCache[trip.id] = _parseSeats(response['seats']);
      return trip;
    } on FirebaseFunctionsException catch (error) {
      throw TripActionException(_mapTripError(error.code, error.message));
    }
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

  Future<Trip?> cancelTrip({
    required String tripId,
    String? cancellationReason,
  }) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'cancelTrip',
        data: {
          'tripId': tripId,
          if ((cancellationReason ?? '').trim().isNotEmpty)
            'cancellationReason': cancellationReason!.trim(),
        },
      );
      return _parseTrip(response['trip']);
    } on FirebaseFunctionsException catch (error) {
      throw TripActionException(_mapTripError(error.code, error.message));
    }
  }

  Future<Trip?> _reviewTrip({
    required String tripId,
    required TripStatus status,
    String? rejectionReason,
  }) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'reviewTrip',
        data: {
          'tripId': tripId,
          'status': status.value,
          ...?rejectionReason == null
              ? null
              : {'rejectionReason': rejectionReason},
        },
      );
      return _parseTrip(response['trip']);
    } on FirebaseFunctionsException catch (error) {
      throw TripActionException(_mapTripError(error.code, error.message));
    }
  }

  Trip? _parseTrip(dynamic value) {
    if (value is! Map) {
      return null;
    }
    return Trip.fromJson(_toMap(value));
  }

  List<Trip> _parseTrips(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((trip) => Trip.fromJson(_toMap(trip)))
        .toList();
  }

  List<TripSeat> _parseSeats(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((seat) => TripSeat.fromJson(_toMap(seat)))
        .toList();
  }

  Map<String, dynamic> _toMap(Map value) {
    return value.map((key, data) => MapEntry('$key', data));
  }

  String _mapTripError(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();

    switch (code) {
      case 'not-found':
        return 'Sefer bulunamadı.';
      case 'permission-denied':
        return 'Bu işlem için yeterli yetkiniz bulunmuyor.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulaşılamadı. Lütfen daha sonra tekrar deneyin.';
      case 'failed-precondition':
      case 'invalid-argument':
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sefer işlemi tamamlanamadı.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sefer işlemi tamamlanamadı.';
    }
  }
}

class TripActionException implements Exception {
  const TripActionException(this.message);

  final String message;
}
