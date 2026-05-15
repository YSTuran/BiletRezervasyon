import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/trip.dart';
import '../models/trip_search_filter.dart';
import '../models/trip_sort_option.dart';

class TripListViewModel extends BaseViewModel {
  static const int pageSize = 10;

  TripListViewModel({required TripRepository repository, required this.role})
    : _repository = repository;

  final TripRepository _repository;
  final UserRole role;

  List<Trip> _trips = const [];
  String? _errorMessage;
  TripSearchFilter _filter = const TripSearchFilter();
  int _currentPageIndex = 0;

  List<Trip> get trips => _trips;
  int get currentPageIndex => _currentPageIndex;
  int get currentPageNumber => _currentPageIndex + 1;
  bool get showsFilters => role == UserRole.normalUser;

  List<Trip> get filteredTrips {
    final originQuery = _normalizeSearchText(_filter.originQuery);
    final destinationQuery = _normalizeSearchText(_filter.destinationQuery);

    final filtered = _trips.where((trip) {
      if (_filter.transportType != null &&
          trip.transportType != _filter.transportType) {
        return false;
      }

      if (originQuery.isNotEmpty &&
          !_normalizeSearchText(trip.origin).contains(originQuery)) {
        return false;
      }

      if (destinationQuery.isNotEmpty &&
          !_normalizeSearchText(trip.destination).contains(destinationQuery)) {
        return false;
      }

      final departureDate = _filter.departureDate;
      if (departureDate != null &&
          !_isSameCalendarDay(trip.departureAt, departureDate)) {
        return false;
      }

      return true;
    }).toList();

    filtered.sort(_tripComparatorFor(_filter.sortOption));
    return filtered;
  }

  List<Trip> get pagedTrips {
    final filtered = filteredTrips;
    if (filtered.isEmpty) {
      return const [];
    }

    final start = _currentPageIndex * pageSize;
    final clampedStart = start.clamp(0, filtered.length);
    final end = (clampedStart + pageSize).clamp(0, filtered.length);
    return filtered.sublist(clampedStart, end);
  }

  int get totalPages {
    final count = filteredTrips.length;
    if (count == 0) {
      return 1;
    }
    return ((count - 1) ~/ pageSize) + 1;
  }

  bool get canGoPrevious => _currentPageIndex > 0;
  bool get canGoNext => _currentPageIndex < totalPages - 1;

  String? get errorMessage => _errorMessage;
  TripSearchFilter get filter => _filter;
  TransportType? get transportFilter => _filter.transportType;
  String get originQuery => _filter.originQuery;
  String get destinationQuery => _filter.destinationQuery;
  DateTime? get departureDateFilter => _filter.departureDate;
  TripSortOption get sortOption => _filter.sortOption;
  bool get hasActiveFilters => _filter.hasActiveFilters;

  String get title => switch (role) {
    UserRole.normalUser => 'Aktif Seferler',
    UserRole.companyOfficer => 'Şirketime Ait Seferler',
    UserRole.admin => 'Tüm Seferler',
  };

  String get emptyMessage {
    if (_filter.hasActiveFilters) {
      return 'Seçili filtrelere uygun sefer bulunmuyor.';
    }

    return switch (role) {
      UserRole.normalUser =>
        'Yaklasan veya yolda olan gosterilecek sefer bulunmuyor.',
      UserRole.companyOfficer => 'Şirketinize ait kayıtlı sefer bulunmuyor.',
      UserRole.admin => 'Sistemde kayıtlı sefer bulunmuyor.',
    };
  }

  bool get canCreateTrip =>
      role == UserRole.companyOfficer &&
      _repository.canCurrentOfficerCreateTrips;

  String? get tripCreationHintMessage => role == UserRole.companyOfficer
      ? _repository.currentOfficerTripCreationBlockMessage
      : null;

  void updateTransportFilter(TransportType? transportType) {
    if (_filter.transportType == transportType) {
      return;
    }
    _filter = _filter.copyWith(transportType: transportType);
    _resetPage();
    notifyListeners();
  }

  void updateOriginQuery(String value) {
    if (_filter.originQuery == value) {
      return;
    }
    _filter = _filter.copyWith(originQuery: value);
    _resetPage();
    notifyListeners();
  }

  void updateDestinationQuery(String value) {
    if (_filter.destinationQuery == value) {
      return;
    }
    _filter = _filter.copyWith(destinationQuery: value);
    _resetPage();
    notifyListeners();
  }

  void updateDepartureDateFilter(DateTime? value) {
    final currentValue = _filter.departureDate;
    if (currentValue == value ||
        (currentValue != null &&
            value != null &&
            _isSameCalendarDay(currentValue, value))) {
      return;
    }
    _filter = _filter.copyWith(departureDate: value);
    _resetPage();
    notifyListeners();
  }

  void updateSortOption(TripSortOption value) {
    if (_filter.sortOption == value) {
      return;
    }
    _filter = _filter.copyWith(sortOption: value);
    _resetPage();
    notifyListeners();
  }

  void clearFilters() {
    if (!_filter.hasActiveFilters) {
      return;
    }
    _filter = const TripSearchFilter();
    _resetPage();
    notifyListeners();
  }

  void goToPreviousPage() {
    if (!canGoPrevious) {
      return;
    }
    _currentPageIndex--;
    notifyListeners();
  }

  void goToNextPage() {
    if (!canGoNext) {
      return;
    }
    _currentPageIndex++;
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
      _clampPage();
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Seferler su anda yuklenemedi.';
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }

  void _resetPage() {
    _currentPageIndex = 0;
  }

  void _clampPage() {
    final maxPageIndex = totalPages - 1;
    if (_currentPageIndex > maxPageIndex) {
      _currentPageIndex = maxPageIndex;
    }
    if (_currentPageIndex < 0) {
      _currentPageIndex = 0;
    }
  }

  bool _isSameCalendarDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll('i\u0307', 'i')
        .replaceAll('\u0131', 'i')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u015f', 's')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u00e7', 'c')
        .trim();
  }

  int Function(Trip, Trip) _tripComparatorFor(TripSortOption sortOption) {
    return switch (sortOption) {
      TripSortOption.departureAscending =>
        (left, right) => left.departureAt.compareTo(right.departureAt),
      TripSortOption.priceAscending =>
        (left, right) => left.priceMinor.compareTo(right.priceMinor),
      TripSortOption.priceDescending =>
        (left, right) => right.priceMinor.compareTo(left.priceMinor),
      TripSortOption.durationAscending =>
        (left, right) => left.arrivalAt
            .difference(left.departureAt)
            .compareTo(right.arrivalAt.difference(right.departureAt)),
    };
  }
}
