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

  TransportType _transportType = TransportType.bus;

  TransportType get transportType => _transportType;

  void updateTransportType(TransportType transportType) {
    if (_transportType == transportType) {
      return;
    }
    _transportType = transportType;
    notifyListeners();
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

    setBusy(true);
    try {
      return await _repository.createTrip(
        transportType: _transportType,
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
