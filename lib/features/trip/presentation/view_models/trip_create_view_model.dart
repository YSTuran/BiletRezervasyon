import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../../company/data/repositories/company_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/seat_capacity_policy.dart';
import '../../domain/models/trip.dart';

class TripFormException implements Exception {
  const TripFormException(this.message);

  final String message;
}

class TripCreateViewModel extends BaseViewModel {
  TripCreateViewModel({required TripRepository repository})
    : _repository = repository;

  final TripRepository _repository;
  bool _hasLoaded = false;
  String? _loadErrorMessage;

  bool get hasLoaded => _hasLoaded;
  TransportType? get transportType => _repository.currentOfficerTransportType;
  bool get canCreateTrip => _repository.canCurrentOfficerCreateTrips;
  String get blockedMessage =>
      _loadErrorMessage ??
      _repository.currentOfficerTripCreationBlockMessage ??
      'Sefer oluşturulamıyor.';

  Future<void> load() async {
    if (isBusy || _hasLoaded) {
      return;
    }

    setBusy(true);
    try {
      await _repository.refreshCurrentOfficerCompany();
    } on CompanyActionException catch (error) {
      _loadErrorMessage = error.message;
    } finally {
      _hasLoaded = true;
      setBusy(false);
    }
  }

  Future<Trip?> createTrip({
    required String origin,
    required String destination,
    required DateTime departureAt,
    required DateTime arrivalAt,
    required int seatCapacity,
    required int priceMinor,
  }) async {
    if (isBusy) {
      return null;
    }

    final normalizedOrigin = origin.trim();
    final normalizedDestination = destination.trim();

    if (normalizedOrigin.isEmpty || normalizedDestination.isEmpty) {
      throw const TripFormException('Kalkış ve varış alanları zorunludur.');
    }
    if (normalizedOrigin.toLowerCase() == normalizedDestination.toLowerCase()) {
      throw const TripFormException(
        'Kalkış ve varış noktası farklı olmalıdır.',
      );
    }
    if (!departureAt.isBefore(arrivalAt)) {
      throw const TripFormException(
        'Varış saati kalkış saatinden sonra olmalıdır.',
      );
    }
    if (seatCapacity <= 0) {
      throw const TripFormException(
        'Koltuk kapasitesi sıfırdan büyük olmalıdır.',
      );
    }
    if (priceMinor <= 0) {
      throw const TripFormException('Fiyat sifirdan buyuk olmalidir.');
    }

    final selectedTransportType = transportType;
    if (!canCreateTrip || selectedTransportType == null) {
      throw TripFormException(blockedMessage);
    }
    if (!SeatCapacityPolicy.isAllowed(
      transportType: selectedTransportType,
      seatCapacity: seatCapacity,
    )) {
      throw const TripFormException(
        'Koltuk kapasitesi seçili ulaşım türü için geçerli değil.',
      );
    }

    setBusy(true);
    try {
      return await _repository.createTrip(
        transportType: selectedTransportType,
        origin: normalizedOrigin,
        destination: normalizedDestination,
        departureAt: departureAt,
        arrivalAt: arrivalAt,
        seatCapacity: seatCapacity,
        priceMinor: priceMinor,
      );
    } on TripActionException catch (error) {
      throw TripFormException(error.message);
    } on CompanyActionException catch (error) {
      throw TripFormException(error.message);
    } finally {
      setBusy(false);
    }
  }
}
