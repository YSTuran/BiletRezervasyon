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
  TransportType? _transportFilter;

  List<Trip> get trips => _trips;
  List<Trip> get filteredTrips {
    final filter = _transportFilter;
    if (filter == null) {
      return _trips;
    }
    return _trips.where((trip) => trip.transportType == filter).toList();
  }

  String? get errorMessage => _errorMessage;
  TransportType? get transportFilter => _transportFilter;

  String get title => switch (role) {
    UserRole.normalUser => 'Tum Seferler',
    UserRole.companyOfficer => 'Sirketime Ait Seferler',
    UserRole.admin => 'Tum Seferler',
  };

  String get emptyMessage {
    if (_transportFilter != null) {
      return 'Secili ulasim turunde gosterilecek sefer bulunmuyor.';
    }

    return switch (role) {
      UserRole.normalUser => 'Gosterilecek sefer bulunmuyor.',
      UserRole.companyOfficer => 'Sirketinize ait kayitli sefer bulunmuyor.',
      UserRole.admin => 'Sistemde kayitli sefer bulunmuyor.',
    };
  }

  bool get canCreateTrip =>
      role == UserRole.companyOfficer &&
      _repository.canCurrentOfficerCreateTrips;

  String? get tripCreationHintMessage => role == UserRole.companyOfficer
      ? _repository.currentOfficerTripCreationBlockMessage
      : null;

  void updateTransportFilter(TransportType? transportType) {
    if (_transportFilter == transportType) {
      return;
    }
    _transportFilter = transportType;
    notifyListeners();
  }

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
