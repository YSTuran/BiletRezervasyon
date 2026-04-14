import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/trip.dart';

class TripFormException implements Exception {
  const TripFormException(this.message);

  final String message;
}

class TripCreateViewModel extends BaseViewModel {
  TripCreateViewModel({required TripRepository repository})
    : _repository = repository;

  final TripRepository _repository;

  TransportType? get transportType => _repository.currentOfficerTransportType;
  bool get canCreateTrip => _repository.canCurrentOfficerCreateTrips;
  String get blockedMessage =>
      _repository.currentOfficerTripCreationBlockMessage ??
      'Sefer olusturulamiyor.';

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
      throw const TripFormException('Kalkis ve varis alanlari zorunludur.');
    }
    if (normalizedOrigin.toLowerCase() == normalizedDestination.toLowerCase()) {
      throw const TripFormException(
        'Kalkis ve varis noktasi farkli olmalidir.',
      );
    }
    if (!departureAt.isBefore(arrivalAt)) {
      throw const TripFormException(
        'Varis saati kalkis saatinden sonra olmalidir.',
      );
    }
    if (seatCapacity <= 0) {
      throw const TripFormException(
        'Koltuk kapasitesi sifirdan buyuk olmalidir.',
      );
    }
    if (priceMinor <= 0) {
      throw const TripFormException('Fiyat sifirdan buyuk olmalidir.');
    }

    final selectedTransportType = transportType;
    if (!canCreateTrip || selectedTransportType == null) {
      throw TripFormException(blockedMessage);
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
    } finally {
      setBusy(false);
    }
  }
}
