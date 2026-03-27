import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/trip.dart';

class TripListViewModel extends BaseViewModel {
  TripListViewModel({required TripRepository repository, required this.role})
    : _repository = repository;

  final TripRepository _repository;
  final UserRole role;

  List<Trip> _trips = const [];
  String? _errorMessage;

  List<Trip> get trips => _trips;
  String? get errorMessage => _errorMessage;

  String get title => switch (role) {
    UserRole.normalUser => 'Uygun Seferler',
    UserRole.companyOfficer => 'Sefer Yonetimi',
    UserRole.admin => 'Tum Seferler',
  };

  String get emptyMessage => switch (role) {
    UserRole.normalUser => 'Gosterilecek uygun sefer bulunmuyor.',
    UserRole.companyOfficer => 'Size ait kayitli sefer bulunmuyor.',
    UserRole.admin => 'Sistemde kayitli sefer bulunmuyor.',
  };

  bool get canCreateTrip => role == UserRole.companyOfficer;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      _trips = await _repository.fetchTrips(role: role);
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Seferler su anda yuklenemedi.';
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }
}
