import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/reservation_repository.dart';
import '../../domain/models/reservation.dart';

class ReservationListViewModel extends BaseViewModel {
  ReservationListViewModel({
    required ReservationRepository repository,
    required this.role,
  }) : _repository = repository;

  final ReservationRepository _repository;
  final UserRole role;

  List<Reservation> _reservations = const [];
  String? _errorMessage;

  List<Reservation> get reservations => _reservations;
  String? get errorMessage => _errorMessage;

  String get title => switch (role) {
    UserRole.normalUser => 'Rezervasyonlarım',
    UserRole.companyOfficer => 'Rezervasyon Talepleri',
    UserRole.admin => 'Tüm Rezervasyonlar',
  };

  String get emptyMessage => switch (role) {
    UserRole.normalUser => 'Henüz bir rezervasyonunuz bulunmuyor.',
    UserRole.companyOfficer =>
      'Şirket seferleri için henüz bir rezervasyon talebi bulunmuyor.',
    UserRole.admin => 'Gosterilecek rezervasyon bulunmuyor.',
  };

  bool canCancel(Reservation reservation) {
    return role == UserRole.normalUser &&
        (reservation.status == ReservationStatus.pendingApproval ||
            reservation.status == ReservationStatus.approved);
  }

  bool canReview(Reservation reservation) {
    return role == UserRole.companyOfficer &&
        reservation.status == ReservationStatus.pendingApproval;
  }

  bool canPay(Reservation reservation) {
    return role == UserRole.normalUser &&
        reservation.status == ReservationStatus.approved;
  }

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      _reservations = await _repository.fetchReservations();
      notifyListeners();
    } on ReservationActionException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }

  Future<Reservation?> cancelReservation(String reservationId) async {
    return _applyAction(() async {
      return _repository.cancelReservation(reservationId: reservationId);
    });
  }

  Future<Reservation?> approveReservation(String reservationId) async {
    return _applyAction(() async {
      return _repository.approveReservation(reservationId: reservationId);
    });
  }

  Future<Reservation?> rejectReservation({
    required String reservationId,
    required String rejectionReason,
  }) async {
    return _applyAction(() async {
      return _repository.rejectReservation(
        reservationId: reservationId,
        rejectionReason: rejectionReason,
      );
    });
  }

  Future<Reservation?> _applyAction(
    Future<Reservation?> Function() action,
  ) async {
    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      final updatedReservation = await action();
      if (updatedReservation != null) {
        _replaceReservation(updatedReservation);
        _errorMessage = null;
        notifyListeners();
      }
      return updatedReservation;
    } on ReservationActionException {
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  void _replaceReservation(Reservation updatedReservation) {
    final index = _reservations.indexWhere(
      (reservation) => reservation.id == updatedReservation.id,
    );
    if (index == -1) {
      _reservations = [updatedReservation, ..._reservations];
      return;
    }

    final nextReservations = [..._reservations];
    nextReservations[index] = updatedReservation;
    _reservations = nextReservations;
  }
}
