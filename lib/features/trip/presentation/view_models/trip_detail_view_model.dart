import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_seat.dart';

class TripDetailViewModel extends BaseViewModel {
  TripDetailViewModel({
    required TripRepository repository,
    required this.tripId,
    required this.role,
  }) : _repository = repository;

  final TripRepository _repository;
  final String tripId;
  final UserRole role;

  Trip? _trip;
  List<TripSeat> _seats = const [];
  String? _errorMessage;

  Trip? get trip => _trip;
  List<TripSeat> get seats => _seats;
  String? get errorMessage => _errorMessage;

  bool get showManagementHint => role != UserRole.normalUser;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      _trip = await _repository.fetchTripById(tripId);
      if (_trip == null) {
        _errorMessage = 'Sefer bulunamadi.';
        _seats = const [];
      } else {
        _seats = await _repository.fetchTripSeats(tripId: tripId);
      }
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Sefer detaylari yuklenemedi.';
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }
}
