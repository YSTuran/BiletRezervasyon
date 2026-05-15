import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../../reservation/data/repositories/reservation_repository.dart';
import '../../../reservation/domain/models/reservation.dart';
import '../../../reservation/domain/models/trip_reservation_availability.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_seat.dart';

class TripDetailViewModel extends BaseViewModel {
  TripDetailViewModel({
    required TripRepository repository,
    required ReservationRepository reservationRepository,
    required this.tripId,
    required this.role,
  }) : _repository = repository,
       _reservationRepository = reservationRepository;

  final TripRepository _repository;
  final ReservationRepository _reservationRepository;
  final String tripId;
  final UserRole role;

  Trip? _trip;
  List<TripSeat> _seats = const [];
  String? _errorMessage;
  Set<String> _blockedSeatIds = <String>{};
  Reservation? _currentUserReservation;

  Trip? get trip => _trip;
  List<TripSeat> get seats => _seats;
  String? get errorMessage => _errorMessage;
  Set<String> get blockedSeatIds => _blockedSeatIds;
  Reservation? get currentUserReservation => _currentUserReservation;

  bool get showManagementHint => role != UserRole.normalUser;
  bool get canReviewTrip =>
      role == UserRole.admin && _trip?.status == TripStatus.pendingApproval;
  bool get canCreateReservation =>
      role == UserRole.normalUser && _trip?.status == TripStatus.approved;

  bool isSeatBlocked(String seatId) => _blockedSeatIds.contains(seatId);

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
        _blockedSeatIds = <String>{};
        _currentUserReservation = null;
      } else {
        _seats = await _repository.fetchTripSeats(tripId: tripId);
        if (role == UserRole.normalUser) {
          final availability = await _reservationRepository
              .fetchTripReservationAvailability(tripId: tripId);
          _applyReservationAvailability(availability);
        } else {
          _blockedSeatIds = <String>{};
          _currentUserReservation = null;
        }
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
      return updatedTrip;
    } catch (_) {
      _errorMessage = 'Sefer onaylanamadi.';
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
      return updatedTrip;
    } catch (_) {
      _errorMessage = 'Sefer reddedilemedi.';
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  Future<Reservation?> createReservation({required String tripSeatId}) async {
    if (!canCreateReservation) {
      throw const TripReviewException(
        'Bu sefer için rezervasyon oluşturulamaz.',
      );
    }
    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      final reservation = await _reservationRepository.createReservation(
        tripId: tripId,
        tripSeatId: tripSeatId,
      );
      _blockedSeatIds = {..._blockedSeatIds, tripSeatId};
      _currentUserReservation = reservation;
      _errorMessage = null;
      notifyListeners();
      return reservation;
    } on ReservationActionException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      throw TripReviewException(error.message);
    } finally {
      setBusy(false);
    }
  }

  void _applyReservationAvailability(TripReservationAvailability availability) {
    _blockedSeatIds = availability.blockedSeatIds;
    _currentUserReservation = availability.currentUserActiveReservation;
  }
}

class TripReviewException implements Exception {
  const TripReviewException(this.message);

  final String message;
}
