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
  bool get canReviewTrip =>
      role == UserRole.admin && _trip?.status == TripStatus.pendingApproval;

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

  Future<Trip?> approveTrip() async {
    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      final updatedTrip = await _repository.approveTrip(tripId: tripId);
      if (updatedTrip == null) {
        _errorMessage = 'Sefer bulunamadi.';
        notifyListeners();
        return null;
      }

      _trip = updatedTrip;
      _errorMessage = null;
      notifyListeners();
      return updatedTrip;
    } catch (_) {
      _errorMessage = 'Sefer onaylanamadi.';
      notifyListeners();
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  Future<Trip?> rejectTrip(String rejectionReason) async {
    final trimmedReason = rejectionReason.trim();
    if (trimmedReason.isEmpty) {
      throw const TripReviewException('Red nedeni zorunludur.');
    }

    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      final updatedTrip = await _repository.rejectTrip(
        tripId: tripId,
        rejectionReason: trimmedReason,
      );
      if (updatedTrip == null) {
        _errorMessage = 'Sefer bulunamadi.';
        notifyListeners();
        return null;
      }

      _trip = updatedTrip;
      _errorMessage = null;
      notifyListeners();
      return updatedTrip;
    } catch (_) {
      _errorMessage = 'Sefer reddedilemedi.';
      notifyListeners();
      rethrow;
    } finally {
      setBusy(false);
    }
  }
}

class TripReviewException implements Exception {
  const TripReviewException(this.message);

  final String message;
}
