import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../data/repositories/reservation_repository.dart';
import '../../domain/models/reservation.dart';

class ReservationListViewModel extends BaseViewModel {
  ReservationListViewModel({required ReservationRepository repository})
    : _repository = repository;

  final ReservationRepository _repository;

  List<Reservation> _reservations = const [];

  List<Reservation> get reservations => _reservations;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _reservations = await _repository.fetchReservations();
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }
}
