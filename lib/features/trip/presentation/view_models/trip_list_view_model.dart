import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/trip.dart';

class TripListViewModel extends BaseViewModel {
  TripListViewModel({required TripRepository repository})
    : _repository = repository;

  final TripRepository _repository;

  List<Trip> _trips = const [];

  List<Trip> get trips => _trips;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _trips = await _repository.fetchTrips();
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }
}
